open Arg 
module Ni = Int32

module BinaryArray = struct
  type t = int array
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

module Section = struct
  type t = { offset:int; length:int; name:string; image: BinaryArray.t}
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

let relocs (s,l,_,image) (s_ref,l_ref,_,image_ref) = 
  let relocs = ref [] in
  let i1 = ref s in
  let i2 = ref s_ref in
    while !i1 <= s+l-4 && !i2 <= s_ref+l_ref-4 do
      begin
	let same = ref true in
	  if  image.(!i1) != image_ref.(!i2) then
	    begin
	      let j1 = ref (!i1+1) in
	      let j2 = ref (!i2+1) in
		while !same && !j1 < !i1 + 3 do
		  if image.(!j1) != image_ref.(!j2) then
		    begin
		      same := false
		    end;
		  j1 := !j1+1;
		  j2 := !j2+1;
		done;
	    end;
	  let dw1 = BinaryArray.get_dword image !i1 in
	  let dw2 = BinaryArray.get_dword image_ref !i2 in
	  if not !same (*&& Ni.add dw2 base = dw1*)  then
	    begin
	      relocs := (Ni.of_int !i1,Ni.of_int !i2, dw1, dw2, 4,image)::!relocs;
	      i1 := !i1 + 3;
	      i2 := !i2 + 3;
	    end
      end;
      i1 := !i1 + 1;
      i2 := !i2 + 1;
    done;
    List.rev !relocs

let to_list (s,l,_,im) = Array.fold_right (fun x acc -> x::acc) (Array.sub im s l) []

end

module Symbol = struct
  type t = {name:int; offset:int; backpatch: int list }
end

module Image = struct
  type t = {sections:Section.t list; symbols:Symbol.t list}
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

let list_words name_section (*dict_section*) =
(*  let names = Section.to_list name_section in *)
  let (s,l,_,image) = name_section in
  let get_string i = 
    let lst = 
	List.rev ((Array.fold_left 
	   (fun acc x -> match x with 0 -> acc | _ -> (char_of_int x)::acc)
	   [] (Array.sub image (s+i*32) 32))) in
    let str = String.create (List.length lst) in
      (List.fold_left (fun i x -> str.[i] <- x; i+1) 0 lst);
      str
  in
  let no = l / 32 in
    for i = 0 to no - 1 do
      Printf.printf "Name: %s Len: %d\n" (get_string i) i
    done

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

    "-relocs", String    (fun nm -> reference_file := Some nm), 
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
    "Link with fourk engine";

    "-words", String (fun x -> list_words (Section.find (BinaryFile.read x) "name")),
    "Print words"
  ]
end




let relocate_section (s,e) offs relocs base =
  List.iter 
    (fun (ofs,_,v1,v2,n,image) -> 
       let ptr1,ptr2 = Ni.add (Ni.of_int s) base,Ni.add (Ni.of_int e) base in
	 if v1 >= ptr1 && v1 < ptr2 then
	   begin
	     Printf.printf "Found ptr: %lx\n" v1;
	     let v' = Ni.add v1 (Ni.of_int offs) in
	       BinaryArray.set_dword image (Ni.to_int ofs) v'
	   end
    ) relocs

    



let relocs_in_section (s,l,_,_) = 
  List.fold_left (fun acc r -> let (i,_,_,_,_) = r in if Ni.to_int i >= s && Ni.to_int i < s+l then r::acc else acc) []
  

let print_reloc base1 base2 (ofs,_, v1, v2, n, img) =
  let which = match !Options.which_show with 1 -> base1 | _ -> base2 in
  let addr = function Some x -> x | None -> Ni.of_int 0 in
  let b ofs = Ni.add ofs (Ni.add which (addr !Options.base_address)) in
  if n = 1 then 
    Printf.printf "\t%.4lx: byte\t%.8lx -> %.8lx -> %8ld\n" (b ofs) v1 v2 (Ni.sub v2 v1)
  else 
    Printf.printf "\t%.4lx: dword\t%.8lx -> %.8lx -> %8ld\n" (b ofs) v1 v2 (Ni.sub v2 v1)
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

let list_relocs image ref_image relocate =
  let base1 = BinaryArray.get_dword image 0 in
  let base2 = BinaryArray.get_dword ref_image 0 in
  let delta = Ni.sub base1 base2 in
    if not relocate then
(*
      let sections = Section.take image in
      let print_relocs sec = 
	let _,_,name,_ = sec in List.iter (print_reloc base1 base2) (Section.relocs sec (Section.find ref_image name)) in
      list_sections image print_relocs
*)
()
    else 
      begin
	Printf.printf "Delta: %lx\n" delta;
	let sections = Section.take image in
	let dict = Section.find image "dict" in
	let dict' = Section.find ref_image "dict" in
	let dsptch = Section.find image "dsptch" in
	let (ds,dl,_,_) = dsptch in
	let (s,l,nm,im) = dict in
	let real_end = Section.real_end dict in
	let offs = real_end - ds in 
	let range = ds,ds+dl in
	  Printf.printf "Offset: %d\n" offs;
	  relocate_section range offs (Section.relocs dict dict') base1; 
	  Array.blit image ds image real_end dl;
	  BinaryFile.write image "image2.4ki" (Array.length image)
      end
      
			   
       
     
(*
	 let l = relocs_in_section (s,s+l) diff in
	   List.iter (print_reloc base1 base2) l) sections;
*)  
(* String of character *)

let process_file file_name =        
  let image = BinaryFile.read file_name in
    (match !Options.reference_file with
	 Some ref_nm ->
	   let ref_image = BinaryFile.read ref_nm in
	     list_relocs image ref_image !Options.relocate;
	     ()
       | None -> ());
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
	  Section.fill_all (Section.find target_image "semantic") 0; 
	  Section.fill_all (Section.find target_image "interpret") 0;
	  copy_same_section src_image target_image "dsptch";
	  (*		  copy_same_section src_image target_image "semantic"; 
			  copy_same_section src_image target_image "name"; *)

      BinaryFile.write target_image !Options.link_with (Array.length target_image);

      end;; 

let _ = 
  if Array.length Sys.argv > 1 then
    parse Options.options process_file usage_text
  else usage Options.options usage_text

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
