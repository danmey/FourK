type section = { offset:int; length:int }
type symbol = {id:int; offset:int; backpatch: int list }
type image = {sections:section list; symbols:symbol list}
open Arg 
module Ni = Int32

module Options = struct
  let output_file = ref "a.4ki"
  let reference_file = ref None
  let base_address = ref None
  let which_show = ref 1
  let relocate = ref false
  let list_sections = ref false
  let verbose = ref false
  let brute_force = ref false
  let link_with = ref ""
let options = 
  [
    "-o", String    (fun nm  -> output_file := nm), 
    "Output image file name";

    "-r", String    (fun nm -> reference_file := Some nm), 
    "List relocations";

    "-b", String    (fun hex -> Scanf.sscanf hex "%x" (fun x -> base_address := Some (Ni.of_int x))), 
    "Base address of the image";

    "-R", String    (fun nm -> reference_file := Some nm; relocate := true), 
    "Perform relocation using reference file";

    "-s", Int       (fun i -> which_show := i), 
    "Use base adresses from which file; 1 - reference file";

    "-l", Unit      (fun () -> list_sections := true), 
    "List sections";

    "-v", Unit      (fun () -> verbose := true), 
    "Be verbose, show relocs in teh section list.";

    "--brute-force", Unit (fun () -> brute_force := true), 
    "Be brutal, no relocations, fill garbage with zeroes";

    "-link", String (fun nm -> link_with := nm), 
    "Link with fourk engine"
  ]
end

module BinaryArray = struct
let get_dword arr i = 
  let ni = Ni.of_int in
  let b1 = ni arr.(i+3) in
  let b2 = ni arr.(i+2) in
  let b3 = ni arr.(i+1) in
  let b4 = ni arr.(i+0) in
    Ni.logor (Ni.shift_left b1 24) 
      (Ni.logor (Ni.shift_left b2 16) 
	 (Ni.logor (Ni.shift_left b3 8)
	    b4))

let set_dword arr i dword = 
  let b4 = Ni.to_int (Ni.logand (Ni.shift_right_logical dword 24) (Ni.of_int 255)) in
  let b3 = Ni.to_int (Ni.logand (Ni.shift_right_logical dword 16) (Ni.of_int 255)) in
  let b2 = Ni.to_int (Ni.logand (Ni.shift_right_logical dword 8)  (Ni.of_int 255)) in
  let b1 = Ni.to_int (Ni.logand dword (Ni.of_int 255)) in
    arr.(i+0) <- b1;
    arr.(i+1) <- b2;
    arr.(i+2) <- b3;
    arr.(i+3) <- b4;
    ()
end

module BinaryFile = struct
  let write image nm len = 
    let file = open_out_bin nm in
      Array.iteri (fun i x -> if i < len then output_byte file x) image;
      close_out file

  let read nm =
    let file = open_in_bin nm in
    let size = in_channel_length file in
    let array = Array.make size 0 in
      for i = 0 to size - 1 do
	array.(i) <- input_byte file
      done;
      close_in file;
      array
end

module Section = struct
  let next image o =
    try
      let rec skip_to_section f i = 
	if image.(i) = Char.code '@' && image.(i+1) = Char.code '@' then
	  begin
	    i+2
	  end
	else begin	  
	  f image.(i);
	  skip_to_section f (i+1) 
	end
      in
      let i = skip_to_section (fun _ -> ()) o in
      let name = ref "" in
      let i' = skip_to_section 
	(fun c ->
	   name := !name ^ Printf.sprintf "%c" (char_of_int c)) i
      in
	try 
	  let j = skip_to_section (fun _ -> ()) i' in
	    (i', j - i'-2,!name, image)
	with _ -> (i',Array.length image - i',!name, image)
    with _ -> (0,0,"", image)

  let fill_all (s,l,_,im) v = Array.fill im s l v
  let fill (s,l,_,im) v o n = Array.fill im (s+o) n v

  let take image =
    let rec loop acc = function
      | (0, 0, _,_) -> List.rev acc
      | (o, l, n,_) as section -> loop (section::acc) (next image (o+l))
    in loop [] (next image 0) 

let find image nm =
  List.find (fun (_,_,nm',_) -> nm' = nm) (take image)

let copy (s1,l1,_,src_image) (s2,l2,_,target_image) = Array.blit src_image s1 target_image s2 l1

let real_end (s,l,_,image) =
  let rec zeroes i = 
    if i >= s then
      if image.(i) = 0 then zeroes (i-1)
      else i+1
    else
      i
  in
    zeroes (s+l-1)

let print sec = 
  let (s,l,n,_) = sec in
  let re = s+l-(real_end sec) in
  Printf.printf "name: %s\toffset: %d\tlen: %d\tzeros: %d\n" n s l re

end

let compare image1 image2 base = 
  let size = if Array.length image1 < Array.length image2 then Array.length image1 else Array.length image2 in
  let relocs = ref [] in
  let i = ref 0 in
    while !i < size-4 do
      begin
	let same = ref true in
	  if  image1.(!i) != image2.(!i) then
	    begin
	      let j = ref (!i+1) in
		while !same && !j < !i + 3 do
		  if image1.(!j) != image2.(!j) then
		    begin
		      same := false
		    end;
		  j := !j+1
		done;
	    end;
	  let dw1 = BinaryArray.get_dword image1 !i in
	  let dw2 = BinaryArray.get_dword image2 !i in
	  if not !same && Ni.add dw2 base = dw1 then
	    begin
	      relocs := (Ni.of_int !i, dw1, dw2, 4)::!relocs;
	      i := !i + 3
	    end
      end;
      i := !i + 1
    done;
    List.rev !relocs
  
let relocate_section image relocs base =
  List.iter 
    (fun (ofs,_,v,_) -> 
       let v' = Ni.add v base in
	 BinaryArray.set_dword image (Ni.to_int ofs) v') relocs



let relocs_in_section (s,e,_,_) = 
  List.fold_left (fun acc r -> let (i,_,_,_) = r in if Ni.to_int i >= s && Ni.to_int i < e then r::acc else acc) []
  

let print_reloc base1 base2 (ofs, v1, v2, n) =
  let which = match !Options.which_show with 1 -> base1 | _ -> base2 in
  let addr = function Some x -> x | None -> Ni.of_int 0 in
  let b ofs = Ni.add ofs (Ni.add which (addr !Options.base_address)) in
  if n = 1 then 
    Printf.printf "\t%.4lx: byte\t%.8lx -> %.8lx\n" (b ofs) v1 v2
  else 
    Printf.printf "\t%.4lx: dword\t%.8lx -> %.8lx\n" (b ofs) v1 v2
(*
let nop_jump im = 
  let (s,l,n,_) = next_section im 0 in
    im.(s+10) <- 0x90;
    im.(s+11) <- 0x90;
    im.(s+12) <- 0x90;
    im.(s+13) <- 0x90;
    im.(s+14) <- 0x90
*)


let usage_text = "image4k <options> <file>"

let list_sections image after_sec =
  List.iter (fun x -> Section.print x; after_sec x) (Section.take image)

let list_relocs image ref_image =
  let base1 = BinaryArray.get_dword image 0 in
  let base2 = BinaryArray.get_dword ref_image 0 in
  let ofs = Ni.sub base1 base2 in
  let diff = compare image ref_image ofs in
     list_sections image (fun sec -> List.iter (print_reloc base1 base2) (relocs_in_section sec diff))
     
(*
	 let l = relocs_in_section (s,s+l) diff in
	   List.iter (print_reloc base1 base2) l) sections;
*)  
(* String of character *)

let process_file file_name =        
  let image = BinaryFile.read file_name in
    
    (match !Options.reference_file with
	 Some ref_nm -> 
	   let image = BinaryFile.read file_name in
	   let ref_image = BinaryFile.read ref_nm in
	     list_relocs image ref_image
(*
      if !Options.relocate then
      begin
      let (s,l,n,im) = List.hd sections in
      let rest_sections = List.tl sections in
      let delta = s+l-cut_section f2 (s, l) in
      List.iter (fun (s,l,n,_) -> relocate_section f2 (relocs_in_section (s,s+l) diff) (Ni.of_int (-delta))) rest_sections;
      let len = Array.length f2 in
    (*		      Printf.printf "Blit: %d %d %d\n" (s+l) (s+l - delta) (len - delta- (s+l - delta)); *)
      Array.blit f2 (s+l) f2 (s+l-delta) (len - (s+l)); 
      BinaryFile.write f2 str len;
*)
       | None -> ());
    (*	    if !brute_force then *)
    
    if !Options.list_sections then
      begin
	list_sections (BinaryFile.read file_name) (fun _ -> ())
      end
    else
    if !Options.link_with != "" then
      begin
	print_endline !Options.link_with;
	let target_image = BinaryFile.read !Options.link_with in
	let src_image = image in
	let copy_same_section im im' nm = Section.copy (Section.find im nm) (Section.find im' nm) in
	  copy_same_section src_image target_image "dict"; 
	  (* Fill with nops *)
	  Section.fill (Section.find target_image "dict") 0x90 0 5;
	  Section.fill_all (Section.find target_image "name") 0; 
	  (*		  Section.fill_all (Section.find target_image "semantic") 0; *)
	  Section.fill_all (Section.find target_image "interpret") 0;
	  copy_same_section src_image target_image "dsptch";
	  (*		  copy_same_section src_image target_image "semantic"; 
			  copy_same_section src_image target_image "name"; *)
	  BinaryFile.write target_image !Options.link_with (Array.length target_image);
      end
    let _ = 
      if Array.length Sys.argv > 1 then
	parse Options.options process_file usage_text
      else usage Options.options usage_text

