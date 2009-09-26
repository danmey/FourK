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
    "-r", String    (fun nm  -> reference_file := Some nm), 
    "Reference file for resolving relocations";
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


let next_section image o =
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
	  (i,j - i - 2,!name)
      with _ -> (i,Array.length image - i,!name)
  with _ -> (0,0,"")

let relocs_in_section (s,e) = 
  List.fold_left (fun acc r -> let (i,_,_,_) = r in if Ni.to_int i >= s && Ni.to_int i < e then r::acc else acc) []
  
let cut_section image (s,l) =
  let rec zeroes i = 
    if i >= s then
      if image.(i) = 0 then zeroes (i-1)
      else i+1
    else
      i
  in
    zeroes (s+l-1)

let print_reloc base1 base2 (ofs, v1, v2, n) =
  let which = match !Options.which_show with 1 -> base1 | _ -> base2 in
  let addr = function Some x -> x | None -> Ni.of_int 0 in
  let b ofs = Ni.add ofs (Ni.add which (addr !Options.base_address)) in
  if n = 1 then 
    Printf.printf "\t%.4lx: byte\t%.8lx -> %.8lx\n" (b ofs) v1 v2
  else 
    Printf.printf "\t%.4lx: dword\t%.8lx -> %.8lx\n" (b ofs) v1 v2

let nop_jump im = 
  let (s,l,n) = next_section im 0 in
    im.(s+10) <- 0x90;
    im.(s+11) <- 0x90;
    im.(s+12) <- 0x90;
    im.(s+13) <- 0x90;
    im.(s+14) <- 0x90

let zero_section (s,l) im = Array.fill im s l 0

let take_sections image =
  let rec loop acc = function
    | (0, 0, _) -> List.rev acc
    | (o, l, n) as section -> loop (section::acc) (next_section image (o+l))
  in loop [] (next_section image 0) 

let usage_text = "image4k <options> <file>"
(* String of character *)
let process_file str =        
  let f2 = BinaryFile.read str in
    (match !Options.reference_file with
	 Some nm -> 
	   (let f1 = BinaryFile.read nm in
	    let base1 = BinaryArray.get_dword f1 0 in
	    let base2 = BinaryArray.get_dword f2 0 in
	    let ofs = Ni.sub base1 base2 in
	    let diff = compare f1 f2 ofs in

	    let sections = take_sections f2 in
	      List.iter 
		(fun (s,l,n) -> 
		   Printf.printf "name: %s\toffset: %d\tlen: %d\tzeros: %d\n" 
		     n s l (s+l-(cut_section f2 (s,l)));
		   let l = relocs_in_section (s,s+l) diff in
		     List.iter (print_reloc base1 base2) l) sections;

	      if !Options.relocate then
		begin
		  let (s,l,n) = List.hd sections in
		  let rest_sections = List.tl sections in
		  let delta = s+l-cut_section f2 (s, l) in
		    List.iter (fun (s,l,n) -> relocate_section f2 (relocs_in_section (s,s+l) diff) (Ni.of_int (-delta))) rest_sections;
		    let len = Array.length f2 in
(*		      Printf.printf "Blit: %d %d %d\n" (s+l) (s+l - delta) (len - delta- (s+l - delta)); *)
		      Array.blit f2 (s+l) f2 (s+l-delta) (len - (s+l)); 
		      BinaryFile.write f2 str len;
		end)
       |  None -> 
	    (*	    if !brute_force then *)

	    if !Options.link_with != "" then
	      begin
		print_endline !Options.link_with;
		let im = BinaryFile.read !Options.link_with in
		let sections = take_sections im in
		  List.iter (fun sec ->
			       let (s,l,n) = sec in
				 print_endline n;
				 match n with 
				   | "interpret" -> zero_section (s,l-2) im
				   | "semantic" -> zero_section (s,l-2) im
				   | "name" -> zero_section (s,l-2) im
				   | "dict" -> (
(*				       Array.blit f2 0 im (s+6) (Array.length f2-6); *)
				       let (s,l,n) = next_section im 0 in
					 im.(s+10) <- 0x90;
					 im.(s+11) <- 0x90;
					 im.(s+12) <- 0x90;
					 im.(s+13) <- 0x90;
					 im.(s+14) <- 0x90)
				   | _ -> ()) sections;
		      BinaryFile.write im !Options.link_with (Array.length im);
	      end
    )
      
    
    
    let _ = 
      if Array.length Sys.argv > 1 then
	parse Options.options process_file usage_text
      else usage Options.options usage_text

