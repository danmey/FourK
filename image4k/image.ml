open Arg 
module Ni = Int32

module BinaryArray = struct
  type t = int array

(* Get the value from byte array as dword *)
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

  let relocs image image_ref = 
    let relocs = ref [] in
    let i1 = ref 0 in
    let i2 = ref 0 in
    let l = Array.length image in
    let l_ref = Array.length image_ref in
      while !i1 <= l-4 && !i2 <= l_ref-4 do
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


let to_string sec = 
  let re = sec.offset + sec.len - sec.real_len  in
  Printf.sprintf "name: %16s\toffset: %6d\tlen: %6d\tzeros: %6d" sec.name sec.offset sec.len re


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

module Words = struct
  type opcode = Prefix32 of int * int32 | Prefix of int * int | Opcode of int

  type code = Bytecode of opcode list | Core of int array

  type t =
      { name:string; 
	offset:int; 
	mutable index:int; 
	len:int; 
	code:code;
	called_by:t list; 
	mutable used:bool; 
	prefix:bool }

  let to_string w = 
      Printf.sprintf "Name: %.16s\tOffset: %d\tLen: %d\tIndex: %d\tUsed: %b" w.name w.offset w.len w.index w.used

    let bytecode_id = function
      | Prefix (id,_) -> id
      | Prefix32 (id,_) -> id
      | Opcode id -> id

    let dword b1' b2' b3' b4' =
      let b1 = Ni.of_int b1' in
      let b2 = Ni.of_int b2' in
      let b3 = Ni.of_int b3' in
      let b4 = Ni.of_int b4' in
	Ni.logor (Ni.shift_left b1 24) 
	  (Ni.logor (Ni.shift_left b2 16) 
	     (Ni.logor (Ni.shift_left b3 8)
		b4))

    let disassemble_word lst = 
      let rec disassemble_word' =
	function
	  | []                           -> []
	  | a::i::xs when a = 0 || a = 2 || a = 3 || a = 4 -> (Prefix (a, i))::(disassemble_word' xs)
	  | 1::b1::b2::b3::b4::xs                          -> (Prefix32 (1, (dword b4 b3 b2 b1)))::(disassemble_word' xs)
	  | c::xs                                          -> (Opcode c)::(disassemble_word' xs)
      in
	match lst with
	  | 255::xs -> Bytecode (disassemble_word' xs)
	  | s::xs -> Core (Array.of_list xs)
	  | [] -> Core (Array.make 0 0)

    let make_word i (o,l) name code = 
      { name   =name; 
        index  = i  ; 
	offset = o  ; 
	len    = l  ; 
	code   = disassemble_word code;
	used   = false;
	called_by = [];
	prefix = i < 5;
      } 


    let words (code_sec,name_sec) =

      let word_image = Section.to_list code_sec in
	
      let rec drop n = function
	| []               -> []
	| x::xs when n > 0 -> drop (n-1) xs
	| xs               -> xs 
      in
	
      let rec offsets lst =
	
	let rec drop_bytecode n = function
	  | [] -> [],n
	  | 255::255::_                  -> [],n
	  | x::_::_::_::_::xs when x = 1 -> drop_bytecode (n+5) xs
	  | x::_::xs          when x < 5 -> drop_bytecode (n+2) xs
	  | 255::xs as l                 -> l,n
	  | x::xs                        -> drop_bytecode (n+1) xs in
	let next = drop_bytecode 0 in
	let rec offsets' prev offset = function
	  | []                -> []
	  | 255::255::_       -> []
          | 255::xs           -> let xs',n = next xs in (offset, n+1)::(offsets' true  (offset+n+1) xs')
	  | n::xs             ->                        (offset, n+1)::(offsets' false (offset+n+1) (drop n xs)) in
	  (* Exclude last element *)
	  offsets' false 0 lst in
      let ofs = offsets word_image in

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
				  | _ -> (char_of_int x)::acc) [] (Array.sub name_sec.Section.image (i*32) 32)))
      in

      let names =
	let rec names' i = 
	  if i * 32 + 32 <= name_sec.Section.len then
	    let n = name i in
	      if n = "" then names' (i+1) else n::(names' (i+1))
	  else [] in
	  names' 0
      in
	
	Printf.printf "Offsets: %d\nNames: %d\n" (List.length ofs) (List.length names);
	let names = List.rev (drop (List.length names - List.length ofs) (List.rev names)) in
	  
	let words_pre = List.combine ofs names in

	let words_list = List.rev (snd (List.fold_left 
					  (fun (i,acc) ((o,l),name) -> 
					     let ar = Array.sub code_sec.Section.image o l in
					     let code = Array.to_list ar in
					       (i+1), (make_word i (o,l) name code)::acc
					  ) 
					  (0,[]) words_pre)) in
	let words_ar = Array.of_list words_list in

	let traverse words word =
	  let rec traverse' words word = 
	    match word.code with
	      | Core a -> word.used <- true
	      | Bytecode b -> List.iter
		  (function x ->
		     let id = bytecode_id x in
		     let word' = words.(id) in
		       if not word'.used then
			 begin
			   word'.used <- true;
			   traverse' words word'
			 end
		  ) b in
	    word.used <- true;
	    traverse' words word in

	let last_word = words_ar.(Array.length words_ar-1) in
	  traverse words_ar last_word;
	  words_list

  let string_of_bytecode word_arr code =
    let rec loop =
      function
	| []              -> []
	| (Prefix (i,v)  )::xs -> (Printf.sprintf "%s(%n)"  word_arr.(i).name v) :: (loop xs)
	| (Prefix32 (i,v))::xs -> (Printf.sprintf "%s(%lx)" word_arr.(i).name v) :: (loop xs)
	| (Opcode i      )::xs -> word_arr.(i).name                              :: (loop xs) in
      String.concat " " (loop code)

      
  let emit words name_section section = 
    let dw dword =
      let b4 = Ni.to_int (Ni.logand (Ni.shift_right_logical dword 24) (Ni.of_int 255)) in
      let b3 = Ni.to_int (Ni.logand (Ni.shift_right_logical dword 16) (Ni.of_int 255)) in
      let b2 = Ni.to_int (Ni.logand (Ni.shift_right_logical dword 8)  (Ni.of_int 255)) in
      let b1 = Ni.to_int (Ni.logand dword (Ni.of_int 255)) in
	b1::b2::b3::b4::[] in

    let emit_names w sec = 
      let explode str =
	let rec loop i acc =
	  if i < 0 then acc else
	    loop (i-1) ((String.get str i)::acc) in
	  loop ((String.length str)-1) [] 
      in
	ignore(List.fold_left 
	  (fun i w -> 
	     let str = explode w.name in
	     let arr = Array.make 32 0 in
	       ignore(List.fold_left (fun i x -> arr.(i) <- int_of_char x; i+1) 0 str);
	       Array.blit arr 0 sec.Section.image (32*w.index) 32; i+1) 0 w)
	  in

    let rec emit_bytecode =
      function
	| [] -> []
	| (Prefix   (i,v))::xs -> i::v::(emit_bytecode xs)
	| (Prefix32 (i,v))::xs -> (i::(dw v))@(emit_bytecode xs)
	| (Opcode i      )::xs -> i::(emit_bytecode xs) in

    let rec emit_words i =
      function
	| [] -> i
	| x::xs -> 
	    (match x.code with
	       | Core im -> section.Section.image.(i) <- (Array.length im);
		   Array.blit im 0 section.Section.image (i+1) (Array.length im); 
		   emit_words (i+1+(Array.length im)) xs
	       | Bytecode bc -> 
		   let im = Array.of_list (emit_bytecode bc) in
		     section.Section.image.(i) <- 255;
		     Array.blit im 0 section.Section.image (i+1) (Array.length im); 
		     emit_words (i+1+(Array.length im)) xs) in
    let i = emit_words 0 words in
      emit_names words name_section;
      Printf.printf "%d\n\n" i;
      section.Section.image.(i) <- 255;
      section.Section.image.(i+1) <- 255


  
  let optimise words_list =
    let words_ar = Array.of_list words_list in
    let used = Array.fold_left (fun acc w -> if w.used then w::acc else acc) [] words_ar in
    let used = List.rev (fst (List.fold_right (fun w (acc,i) -> (i,w)::acc,i+1) used ([],0))) in

    let replace_opcode new_op = function
	| Prefix   (_,v) -> Prefix   (new_op,v)
	| Prefix32 (_,v) -> Prefix32 (new_op,v)
	| Opcode    _    -> Opcode new_op in
	
    let rec swap_ids words = 
      let rec loop = function
	| [] -> []
	| w::ws -> 
	    let id    = bytecode_id w in 
	    let w',i' = List.find (fun (i',w') -> id = w'.index) words in
	      (replace_opcode w' w)::(loop ws) in

      let words' = List.map 
	(fun (i,w) -> 
	   match w.code with 
	     | Core _ -> i,w 
	     | Bytecode b -> i, { w with code=Bytecode (loop b) }) words in

      let words' = List.map 
	(fun (i,w) -> 
	   w.index <- i; 
	   words_ar.(i) <- w; w) words' in
	
	List.rev (snd (List.fold_left (fun (ofs,acc) w -> ofs+w.len+1,{w with offset = ofs}::acc) (0,[]) words')) 
    in

    let prefix,non_prefix = List.partition (fun (i,w) -> w.prefix) used in
    let spacer = 
      let rec loop = function 
	  i when i < 5 -> (i,{ name=""; index = i; offset=0; len=1; code=Core [||]; used=true; called_by=[]; prefix=true})::(loop (i+1)) | _ -> [] in
	loop (List.length prefix) 
      in
    let ofs = 5-List.length prefix in
    let used' = prefix @ spacer @ (List.map (fun (i,w) -> (i+ofs,w))) non_prefix in
    let u = swap_ids used' in
      List.iter (fun (i,w) -> Printf.printf "%d: %s\n" i (to_string w)) used';
	u
      
end
module FourkImage = struct
  
  let words image = 
    let module S = Section in
    let name_sec = Image.find_section image "name" in
    let word_sec = Image.find_section image "words" in
      Words.words (word_sec,name_sec)
	
  let stripped_sections = ["interpret";"name";"dsptch";"semantic";]
  let strip image = 
    List.iter (fun x -> if (List.mem x.Section.name stripped_sections) then Section.zero x) image.Image.sections

  let copied_sections = ["words";"name";"semantic"]

  let link base_image image word_count = 
    let dict_section = Image.find_section base_image "dict" in
      Array.fill dict_section.Section.image 4 5 0x90;
      BinaryArray.set_dword dict_section.Section.image 10 word_count;
      List.iter (fun nm -> 
		   let src = Image.find_section image nm in 
		   let dst = Image.find_section base_image nm in
		     Section.copy src dst) copied_sections
end

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
				   let words = Words.optimise (FourkImage.words image) in
(*				   let words = FourkImage.words image in *)
				   let sec = Image.find_section image "words" in
				   let nsec = Image.find_section image "name" in
				     Section.zero sec;
				     Words.emit words nsec sec;
				     FourkImage.link base_image image (Int32.of_int (List.length words));
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
			    List.iter (fun x -> print_endline (Words.to_string x)) words
		       ),
      "Print list of words";
      "-disass", String (fun x ->
			   let image = Image.load x in     
			   let words = FourkImage.words image in 
			   let wordsa = Array.of_list words in
			     List.iter (fun x ->
					  match x.Words.code with
					    | Words.Bytecode lst -> Printf.printf ": %s %s ;\n" x.Words.name (Words.string_of_bytecode wordsa lst)
					    | _ -> ()) words),
      "Disassemble user dictionary";
      "-wrelocs", 
      (let ref_name = ref "" in
	 Tuple [Set_string ref_name; 
		String (fun x ->
			  let image = Image.load x in  
			  let image_ref = Image.load !ref_name in
			  let words = FourkImage.words image in 
			  let words_ref = FourkImage.words image_ref in 
			  let extract_core x acc =
			    match x.Words.code with 
			      | Words.Core c -> (x.Words.name,c)::acc
			      | _ -> acc in
			  let core_words  = List.fold_right extract_core words [] in
			  let core_words' = List.fold_right extract_core words_ref [] in
			  let print_reloc base1 base2 (ofs,_, v1, v2, n, img) =
			    let b ofs = ofs in
			      Printf.printf "\t%.4lx: dword\t%.8lx -> %.8lx -> %8ld\n" (b ofs) v1 v2 (Ni.sub v2 v1) in
			  let pre = List.combine core_words core_words' in
			  let lst = (List.map (fun ((n,o),(_,r)) -> n,Section.relocs r o) pre) in
			    List.iter (fun (nm,rs) ->
					 Printf.printf "%s\n" nm; 
					 List.iter (fun x -> Printf.printf "\t"; (print_reloc 0 0 x)) rs) lst)]),
      "Show section relocations";
      "-relocs",
      (let ref_name = ref "" in
	 Tuple [Set_string ref_name; 
		String (fun x ->
			  let image = Image.load x in  
			  let image_ref = Image.load !ref_name in
			  let print_reloc base1 base2 (ofs,_, v1, v2, n, img) =
			    Printf.printf "\t%.4lx: dword\t%.8lx -> %.8lx -> %8ld\n" ofs v1 v2 (Ni.sub v2 v1) in
			  let pre = List.combine image.Image.sections image_ref.Image.sections in
			  let lst = (List.map (fun (o,r) -> o.Section.name,Section.relocs o.Section.image r.Section.image) pre) in
			    List.iter (fun (nm,rs) ->
					 Printf.printf "%s\n" nm; 
					 List.iter (fun x -> Printf.printf "\t"; (print_reloc 0 0 x)) rs) lst)]),
      "Show word relocations";

      "-opt", String (fun nm ->  
		 let image = Image.load nm in  
		 let words = FourkImage.words image in 
		 let wordsa = Array.of_list words in
		   List.iter (fun x ->
				match x.Words.code with
				  | Words.Bytecode lst -> Printf.printf ": %s %s ;\n" x.Words.name (Words.string_of_bytecode wordsa lst)
				  | _ -> ()) (Words.optimise words))
      ,"Show optimised dictionary layout"
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

