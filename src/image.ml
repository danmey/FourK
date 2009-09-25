type section = { offset:int; length:int }
type symbol = {id:int; offset:int; backpatch: int list }
type image = {sections:section list; symbols:symbol list}
open Arg 

let output_file = ref "a.4ki"
let reference_file = ref None
let base_address = ref None
let which_show = ref 1
let relocate = ref false
module Ni = Int32

let options = 
  [
    "-o", String (fun nm -> output_file := nm), "Output image file name";
    "-r", String (fun nm -> reference_file := Some nm), "Reference file for resolving relocations";
    "-b", String (fun hex -> (Scanf.sscanf hex "%x" (fun x -> base_address := Some (Ni.of_int x)))), 
    "Base address of the image";
    "-R", String (fun nm -> reference_file := Some nm; relocate := true), "Perform relocation using reference file";
    "-s", Int (fun i -> which_show := i), "Use base adresses from which file; 1 - reference file"
  ]

let dword arr i = 
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

    
let binary_compare image1 image2 start base = 
  let size = if Array.length image1 < Array.length image2 then Array.length image1 else Array.length image2 in
  let relocs = ref [] in
  let i = ref start in
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
	  let dw1 = dword image1 !i in
	  let dw2 = dword image2 !i in
	  if not !same && Ni.add dw2 base = dw1 then
	    begin
	      relocs := (Ni.of_int !i, dw1, dw2, 4)::!relocs;
	      i := !i + 3
	    end
      end;
      i := !i + 1
    done;
    List.rev !relocs

let relocate_image image relocs base =
  List.iter 
    (fun (ofs,_,v,_) -> 
       let v' = Ni.add v base in
	 set_dword image (Ni.to_int ofs) v') relocs

let write_file image nm = 
  let file = open_out_bin nm in
    Array.iter (fun x -> output_byte file x) image;
      close_out file

let load_file nm =
  let file = open_in_bin nm in
  let size = in_channel_length file in
  let array = Array.make size 0 in
    for i = 0 to size - 1 do
      array.(i) <- input_byte file
    done;
    close_in file;
    array
  
let usage_text = "image4k <options> <file>"
(* String of character *)
let process_file str =        
  let f2 = load_file str in
    (match !reference_file with
	 Some nm -> 
	   (let f1 = load_file nm in
	    let base1 = dword f1 0 in
	    let base2 = dword f2 0 in
	    let ofs = Ni.sub base1 base2 in
	    let diff = binary_compare f1 f2 0 ofs in
	      if !relocate then
		begin
		    Printf.printf "ofs: %lx\n" ofs;
		    relocate_image f2 diff ofs; 
		    write_file f2 str;
		end;
		let f2 = load_file str in
		 let base1 = dword f1 0 in
		 let base2 = dword f2 0 in
		 let ofs = Ni.sub base1 base2 in
		  let diff = binary_compare f1 f2 0 ofs  in
		  let which = match !which_show with 1 -> base1 | _ -> base2 in
		  let addr = function Some x -> x | None -> Ni.of_int 0 in
		  let b ofs = Ni.add ofs (Ni.add which (addr !base_address)) in
		    List.iter 
		      (fun (ofs, v1, v2, n) -> 
			 if n = 1 then 
			   Printf.printf "%.4lx: byte\t%.8lx -> %.8lx\n" (b ofs) v1 v2
			 else 
			   Printf.printf "%.4lx: dword\t%.8lx -> %.8lx\n" (b ofs) v1 v2)
		      diff;
	   )
       |  None -> print_endline "not implemented!")
  
  
  
  
  let _ = 
    if Array.length Sys.argv > 1 then
      parse options process_file usage_text
    else usage options usage_text

