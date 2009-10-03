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
  type t = { offset:int; len:int; real_len:int; name:string; image: BinaryArray.t}
  let real_len s e image =
    let rec zeroes i = 
      if i >= s then
	if image.(i) = 0 then zeroes (i-1)
	else i+1-s
      else
	i
    in
    zeroes (e-1)

  let next image o =
    let rec skip_to_section f i = 
      if image.(i) = Char.code '@' && image.(i+1) = Char.code '@'  && image.(i+2) = Char.code '-' then
	i+3
      else 
	begin	  
	  f image.(i);
	  skip_to_section f (i+1) 
	end
    in
    let i = skip_to_section (fun _ -> ()) o in
      if i-3 != o then begin
	i-3, {	offset   = 0;
		name     = "default"; 
		image    = Array.sub image 0 (i-3); 
		len      = i-3;
		real_len = real_len 0 (i-3) image }
	  end
      else
	let name = ref "" in
	let get_name c = name := !name ^ Printf.sprintf "%c" (char_of_int c) in
	  try
	    let i' = skip_to_section get_name i
	    in
	      try 
		let j = skip_to_section (fun _ -> ()) i' in
		let sec_im = Array.sub image i' (j-i'-3) in
		  j-3, { offset   = i'; 
			 name     = !name; 
			 image    = sec_im;
			 len      = j-i'-3; 
			 real_len = real_len i' (j-3) image }
	      with _ -> 
		begin
		  let endo = Array.length image in
		  let sec_im = Array.sub image i' (endo - i') in
		    endo, { offset   = i'; 
			    name     = !name; 
			    image    = sec_im; 
			    len      = endo - i';
			    real_len = real_len i' endo image }
		end
	  with _ -> 
	    let endo = Array.length image in
	      endo, {	offset   = i;
			name     = !name; 
			image    = Array.sub image i (endo - i); 
			len      = endo - i;
			real_len = real_len i endo image }

(*
  let fill_all (s,l,_,im) v = Array.fill im s l v
  let fill (s,l,_,im) v o n = Array.fill im (s+o) n v
*)
  let zero {image=im} = Array.fill im 0 (Array.length im) 0

  let copy src dst = Array.blit src.image 0 dst.image 0 (if src.len < dst.len then src.len else dst.len) 


let to_string sec = 
  let re = sec.offset + sec.len - sec.real_len  in
  Printf.sprintf "name: %16s\toffset: %6d\tlen: %6d\tzeros: %6d" sec.name sec.offset sec.len re

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

let to_list sec = 
  Array.fold_right (fun x acc -> x::acc) sec.image []
end

module Symbol = struct
  type t = {name:int; offset:int; backpatch: int list }
end

module Image = struct
  type t = {rva:Int32.t;sections:Section.t list;}
      
  let save image nm with_tags = 
    let module S = Section in
    let file = open_out_bin nm in
    let write_section sec =
      (* write header *)
      if with_tags then
	begin
	  if not (sec.S.name = "default") then
	    output_string file ("@@-" ^ sec.S.name ^ "@@-");
	end;
      let pos = pos_out file in
      let d = sec.S.offset - pos in
	if d < 0 then begin close_out file; failwith (Printf.sprintf "misplaced section (%s %d %d)" sec.S.name d pos) end
	else begin
	  for i=1 to d do output_byte file 0 done;
	  Array.iter (output_byte file) sec.S.image;
	end
    in
      List.iter write_section image.sections;
      close_out file

  let load nm =
    let file = open_in_bin nm in
    let size = in_channel_length file in
    let array = Array.make size 0 in
      for i = 0 to size - 1 do
	array.(i) <- input_byte file
      done;
      close_in file;
      let rva = BinaryArray.get_dword array 0 in
      let rec loop o acc =
	if o < size then
	  let o',section = Section.next array o in
	    loop o' (section::acc)
	else List.rev acc in
	{ sections = loop 0 []; 
	  rva = rva }

  let find_section image nm = List.find (fun {Section.name=nm'} -> nm' = nm) image.sections
  let print_sections image =
    List.iter (fun x -> print_endline (Section.to_string x)) image.sections

end

module Word = struct
  type t = { name:string; offset:int; index:int; len:int; bytecoded:bool }
  let to_string w = Printf.sprintf "Name: %.32s\tOffset: %d\tLen: %d\tIndex: %d" w.name w.offset w.len w.index
end
module FourkImage = struct
  let words image = 
    let module S = Section in
    let name_section = Image.find_section image "name" in
    let word_section = Image.find_section image "words" in
    let word_image = Section.to_list word_section in
    let rec drop n = function
      | []               -> []
      | x::xs when n > 0 -> drop (n-1) xs
      | xs               -> xs 
    in
    let rec byte_loop prev acc size offset =
      function
	| []                  -> (offset,size)::acc
	| i::_::xs when i < 4 -> byte_loop prev acc (size+2) offset xs
	| 255::xs when prev   -> word_loop true ((offset,size)::acc) (offset+size) (255::xs) 
	| 255::xs             -> word_loop true acc (offset+size) (255::xs) 
	| _::xs               -> byte_loop prev acc (size+1) offset xs
    and word_loop prev acc offset =
      function
	| []      -> acc 
	| 0::_    -> acc
	| 255::xs -> byte_loop prev acc 0 offset xs
	| n::xs   -> word_loop false ((offset,n)::acc) (offset+n) (drop n xs)  
    in

    let sizes = List.rev (word_loop false [] 0 word_image) in
    let implode lst = 
      let str = String.create (List.length lst) in
      let rec loop i = function [] -> str | x::xs -> String.set str i x; loop (i+1) xs 
      in
	loop 0 lst 
    in 
    let name i =  
      implode (List.rev (Array.fold_left 
			   (fun acc x -> 
			      match x with
				| 0 -> acc 
				| _ -> (char_of_int x)::acc) [] (Array.sub name_section.S.image (i*32) 32)))
    in
    let rec names i =
      if i * 32 + 32 <= name_section.S.len then
	let n = name i in
	  if n = "" then names (i+1) else n::(names (i+1))
      else [] 
    in

    let name_list = names 0 in
      Printf.printf "names len %d\n" (List.length name_list);
      Printf.printf "sizes len %d\n" (List.length sizes);
    let word_names = List.combine sizes name_list 
    in
      (List.rev (fst (List.fold_left 
	(fun (lst,i) ((offset,len),name) -> 
	   { Word.offset = offset; 
	     Word.len = len; 
	     Word.name = name;
	     Word.index = i;
	     Word.bytecoded = true;
	   }::lst,i+1) ([],0) word_names)))
	
  let stripped_sections = ["interpret";"name";"dsptch";"semantic";]
  let strip image = 
    List.iter (fun x -> if (List.mem x.Section.name stripped_sections) then Section.zero x) image.Image.sections

  let copied_sections = ["words";"name";"semantic"]

  let link base_image image = 
    let dict_section = Image.find_section base_image "dict" in
      Array.fill dict_section.Section.image 4 5 0x90;
      List.iter (fun nm -> 
		   let src = Image.find_section image nm in 
		   let dst = Image.find_section base_image nm in
		     Section.copy src dst) copied_sections
end

type bytecode = Lit of int | Lit4 of int | Branch of int | Branch0 of int | Label

(*let disas_word bytecode names =
  let rec byte_loop prev acc size =
    function
	(* prefix words *)
      |	[] -> []
      | 0::_::xs | 4::_::xs | 5::_::xs | 6::_::xs ->
	  byte_loop prev acc (size+2) xs 
      | 255::xs when prev  -> word_loop true (size::acc) (255::xs)
      | 255::xs  -> word_loop true acc (255::xs)
      | _::xs -> byte_loop prev acc (size+1) xs
*)



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

    "relocs", String    (fun nm -> reference_file := Some nm), 
    "List relocations";

    "-b", String    (fun hex -> Scanf.sscanf hex "%x" (fun x -> base_address := Some (Ni.of_int x))), 
    "Base address of the image";

    "-R", String    (fun nm -> reference_file := Some nm; relocate := true), 
    "Perform relocation using reference file";
    "-dump-section", 
      (let section_name = ref "" in 
	 Tuple [Set_string section_name; 
		String (fun name -> 
			  let image = Image.load name in
			  let s = Image.find_section image !section_name in
			    Array.iter (fun x -> let x' = char_of_int x in Printf.printf "%c" x') s.Section.image)
	       ]), "Dump given section";
    "-sections", String (fun nm -> 
			   let image = Image.load nm in     
			     Image.print_sections image
			), 
    "List sections";

    "-link", (let image_name = ref "" in 
		Tuple [Set_string image_name; 
		       String (fun core_name -> 
				 let base_image = Image.load core_name in
				 let image = Image.load !image_name in
				 FourkImage.link base_image image;
				   Image.save base_image core_name true)]
	     ),
    "Link with fourk engine";
    "-strip", String 
      (fun nm ->
	 let image = Image.load nm in
	   FourkImage.strip image;
	   Image.save image nm false
      ),
    "Strip sections";
 
    "-words", String (fun x -> 
			let image = Image.load x in     
			let words = FourkImage.words image in 
			  List.iter (fun x -> print_endline (Word.to_string x)) words
		     ),

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

(*
let list_relocs image ref_image relocate =
  let base1 = BinaryArray.get_dword image. 0 in
  let base2 = BinaryArray.get_dword ref_image 0 in
  let delta = Ni.sub base1 base2 in
    if not relocate then

      let sections = Section.take image in
      let print_relocs sec = 
	let _,_,name,_ = sec in List.iter (print_reloc base1 base2) (Section.relocs sec (Section.find ref_image name)) in
      list_sections image print_relocs

()
    else 
      begin
	Printf.printf "Delta: %lx\n" delta;
	let sections = Section.take image in 
	let dict = Image.find_section image "dict" in
	let dict' = Image.find_section ref_image "dict" in
	let dsptch = Image.find_section image "dsptch" in
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
*)      
			   
       
     
(*
	 let l = relocs_in_section (s,s+l) diff in
	   List.iter (print_reloc base1 base2) l) sections;
*)  
(* String of character *)


(*
let process_file file_name =        

  let image = Image.load file_name in
    (match !Options.reference_file with
	 Some ref_nm ->
	   let ref_image = Image.load ref_nm in
	     list_relocs image ref_image !Options.relocate;
	     ()
       | None -> ());
    if !Options.list_sections then
      begin
	list_sections (Image.load file_name) (fun _ -> ())
      end
    else
    if !Options.link_with != "" then
      begin
	print_endline !Options.link_with;
	let target_image = Image.load !Options.link_with in
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

  ()
      end
*) 
  
  let process_file nm = ()
  let _ = 
  if Array.length Sys.argv > 1 then
    parse Options.options process_file usage_text
  else usage Options.options usage_text
;;
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

