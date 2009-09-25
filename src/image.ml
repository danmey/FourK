type section = { offset:int; length:int }
type symbol = {id:int; offset:int; backpatch: int list }
type image = {sections:section list; symbols:symbol list}
open Arg 

let output_file = ref "a.4ki"
let reference_file = ref None
let options = 
  [
    "-o", String (fun nm -> output_file := nm), "Output image file name";
    "-r", String (fun nm -> reference_file := Some nm), "Reference file for resolving relocations"
  ]


let binary_compare image1 image2 = 
  let size = if Array.length image1 < Array.length image2 then Array.length image1 else Array.length image2 in
  let relocs = ref [] in
  let i = ref 0 in
    while !i < size do
      if image1.(!i) != image2.(!i) then
	begin
	  if image1.(!i+1) != image2.(!i+1) then
	    begin 
	      relocs := (!i, 4)::!relocs;
	      i := !i + 4
	    end
	  else
	    begin
	      relocs := (!i, 1)::!relocs;
	      i := !i + 1
	    end;
	end;
      i := !i + 1
    done;
    List.rev !relocs

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
  match !reference_file with
      Some nm -> (let f1 = load_file nm in
		  let f2 = load_file str in
		  let diff = binary_compare f1 f2 in
		  List.iter 
		    (fun (ofs, n) -> 
		       if n = 1 then Printf.printf "%.4x: byte\t%.8x -> %.8x\n" ofs f1.(ofs) f2.(ofs)
		       else Printf.printf "%.4x: dword\t%.8x -> %.8x\n" ofs f1.(ofs) f2.(ofs))
		    diff)
      |  None -> print_endline "not implemented!"
		    
let _ = 
  if Array.length Sys.argv > 1 then
      parse options process_file usage_text
  else usage options usage_text

