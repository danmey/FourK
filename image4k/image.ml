open Arg
module Ni = Int32

let ($) f v = f v
let (%) f g = fun x -> f (g x)

let implode lst =
  let str = String.create (List.length lst) in
  let rec loop i = function [] -> str | x::xs -> String.set str i x; loop (i+1) xs
  in
    loop 0 lst

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

module Image = struct
  type section = { offset   : int;
		   len      : int;
		   real_len : int;
		   markers  : (int*string) list;
		   mutable name     : string;
		   image    : BinaryArray.t }
  type t = { rva:Int32.t;mutable sections:section list; }

  let real_len s e image =
    let rec zeroes i =
      if i >= s then
	if image.(i) = 0 then zeroes (i-1)
	else i+1-s
      else
	i
    in
      zeroes (e-1)

  let find_section image nm = List.find (fun {name=nm'} -> nm' = nm) image.sections

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
		  relocs := (Ni.of_int (!i1-1),Ni.of_int (!i2-1), dw1, dw2, 4,image)::!relocs;
		  i1 := !i1 + 3;
		  i2 := !i2 + 3;
		end
	end;
	i1 := !i1 + 1;
	i2 := !i2 + 1;
      done;
      List.rev !relocs


  let relocate (image, image_ref) src dst =
    let ofs = Int32.of_int (dst.offset - src.offset) in
      Array.blit src.image 0 dst.image 0 (Array.length src.image);
      Array.fill dst.image (Array.length src.image) ((Array.length dst.image)-(Array.length src.image)) 0;
(*      Printf.printf "Image Rva: %lx\n" image.rva; *)
      List.iter (fun sec ->
		   let sec' = find_section image_ref sec.name in
		   let r = relocs sec.image sec'.image in
		     List.iter
		       (fun (o,_,v,_,_,_) ->
			  let v' = Int32.to_int (Int32.sub v image.rva) in
(*			    Printf.printf "v': %lx\n" v; *)
			    if v' >= src.offset && v' < (src.offset + src.len) then
			      begin
(*				Printf.printf "Find reloc in %s at %ld\n" sec'.name o; *)
				BinaryArray.set_dword sec.image (Int32.to_int o) (Int32.add v ofs)
			      end) r) image.sections;
      let n = dst.name in
	dst.name <- src.name;
	src.name <- n


  let to_string sec =
    let re = sec.offset + sec.len - sec.real_len  in
    let markers = List.fold_left (fun acc (nm,ofs) -> acc ^ Printf.sprintf "\nm>offset: %d\tname: %s" nm ofs) "" sec.markers in
      Printf.sprintf "name: %16s\toffset: %6d\tlen: %6d\tzeros: %6d%s" sec.name sec.offset sec.len re markers

  let to_list sec =
    Array.fold_right (fun x acc -> x::acc) sec.image []

  let save image nm =
    let file = open_out_bin nm in
    let write_section sec =
      (* write header *)
(*      Printf.printf "sec.offset: %d\n" sec.offset; *)
      seek_out file sec.offset; 
(*      Printf.printf "OK.\n"; *)
      Array.iter (output_byte file) sec.image;
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

      let section_tab_offset, image_start =
	if
	  array.(0)    = 0x7F
	  && array.(1) = int_of_char 'E'
	  && array.(2) = int_of_char 'L'
	  && array.(3) = int_of_char 'F'
	then
	  (* Parse ELF header etc.
           *
	   *)
	  let entry_point  = BinaryArray.get_dword array 24 in
	  let phdr = BinaryArray.get_dword array 28 in
	  let rva = BinaryArray.get_dword array (40 + Int32.to_int phdr) in
	  let entry_offset = Int32.sub entry_point rva in
	  let section_table_addr_offset = Int32.to_int (Int32.sub entry_offset (Int32.of_int 4)) in
	   let section_table_offset = Int32.to_int (Int32.sub (BinaryArray.get_dword array section_table_addr_offset) rva) in
(*	      Printf.printf "Entry point: %lx\n" entry_point;
	      Printf.printf "Entry offset: %lx\n" entry_offset;
	      Printf.printf "Section tab offset: %d\n" section_table_offset;
*)
	      section_table_offset,(Int32.to_int entry_offset)-4
	else 
	  Int32.to_int (BinaryArray.get_dword array 0),0
      in

      let rec strsz' acc i ofs =
	let b = array.(i+ofs) in
	  if b = 0 then
	    ofs+i+1, implode (List.rev acc)
	  else
	    strsz' ((char_of_int b)::acc) (i+1) ofs in

      let strsz ofs = snd (strsz' [] 0 ofs) in

      let rec loop acc ofs =
	  if BinaryArray.get_dword array ofs <> Int32.zero then
	    let dw = BinaryArray.get_dword array (ofs+28) in
	    let nm = strsz ofs in
(*	      Printf.printf "%s\n" nm; *)
	      loop ((Int32.to_int dw+image_start, nm)::acc) (ofs+32)
	  else 
	    acc
      in
      let sections = List.rev (loop [] section_tab_offset) in
	let rec loop prev_offs = 
	  function
	    | [] -> []
	    | (offs, _)::xs -> (offs - prev_offs)::(loop offs xs)
	in
	let lst x = List.hd (List.rev x) in
	let first_offset,_ = List.hd sections in
	let section_lengths = (loop first_offset (List.tl sections)) @ [Array.length array - (fst (lst sections))] in
	let scs offs len name =
	  let sec_im = Array.sub array offs len in
	    { offset   = offs;
	      name     = name;
	      len      = len;
	      image    = sec_im;
	      markers  = [];
	      real_len = 0  } 
	in
	let sections = sections in
(*	  print_endline "Sections:"; *)
	  let sections = List.fold_left
	    (fun acc ((offs,name),len) ->
(*	       Printf.printf "%s:: %d,%d\n" name offs len; *)
	       let s = scs offs len name in
		 s::acc
	    ) [] (List.combine sections section_lengths)
	  in
	  let sections = List.rev sections in
	  let default_section = scs 0 (List.hd sections).offset "default" in
	  {sections=default_section:: sections; rva = Int32.zero}
  
  let find_marker image nm =
    let fm = List.find (fun (ofs,nm') -> nm' = nm) in
	let sec = List.find
	  (fun x ->
	     try ignore(fm x.markers); true
	     with Not_found -> false) image.sections in
    let (ofs,nm) = fm sec.markers in
      ofs+sec.offset,nm


  let print_sections image =
    List.iter (fun x -> print_endline (to_string x)) image.sections
end

module Symbol = struct
  type t = {name:int; offset:int; backpatch: int list }
end

module Words = struct
  type opcode = 
    | Prefix of int * int
    | Prefix16 of int * int
    | Prefix32 of int * int32
    | Opcode of int 
    | Label of int
    | Branch of int
    | Branch0 of int

  type code = Bytecode of opcode list | Core of int array

  (* TODO: Remove mutable fields completely, let's make a purely functional approach! *)
  type t =
      { name:string;
	offset:int;
	mutable index:int;
	code:code;
	mutable used:int;
	prefix:bool }


    let bytecode_id = function
      | Prefix (id,_)   -> Some id
      | Prefix16 (id,_) -> Some id
      | Prefix32 (id,_) -> Some id
      | Opcode id       -> Some id
      | Label id        -> None
      | Branch id       -> None
      | Branch0 id      -> None

    let bytecode_id' = function
      | Prefix (id,_)    -> None
      | Prefix16 (id,_)  -> None
      | Prefix32 (id,_)  -> None
      | Opcode id        -> Some id
      | Label id         -> None
      | Branch id        -> None
      | Branch0 id       -> None
	  
    let dword b1' b2' b3' b4' =
      let b1 = Ni.of_int b1' in
      let b2 = Ni.of_int b2' in
      let b3 = Ni.of_int b3' in
      let b4 = Ni.of_int b4' in
	Ni.logor (Ni.shift_left b1 24)
	  (Ni.logor (Ni.shift_left b2 16)
	     (Ni.logor (Ni.shift_left b3 8)
		b4))

    let ext_sign b =
      if b land 0x80 = 0x80 then
	Ni.to_int (dword 0xff 0xff 0xff b)
      else
	Ni.to_int (dword 0x00 0x00 0x00 b)

    let ext_sign16 b1 b2 =
      if b2 land 0x80 = 0x80 then
	Ni.to_int (dword 0xff 0xff b2 b1)
      else
	Ni.to_int (dword 0x00 0x00 b2 b1)

    let rec drop n = function
	| []               -> []
	| x::xs when n > 0 -> drop (n-1) xs
	| xs               -> xs

    let rec take n = function
	| []               -> []
	| x::xs when n > 0 -> x::(take (n-1) xs)
	| xs               -> [] 

  let string_of_bytecode names_arr = function
	| Prefix   (i,v) -> Printf.sprintf "%s(%d)"  names_arr.(i) v
	| Prefix32 (i,v) -> Printf.sprintf "%s(%lx)" names_arr.(i) v
	| Prefix16 (i,v) -> Printf.sprintf "%s(%x)" names_arr.(i) v
	| Opcode i       -> names_arr.(i)                             
	| Label l        -> Printf.sprintf "label%d" l                  
	| Branch l       -> Printf.sprintf "goto(label%d)" l          
	| Branch0 l      -> Printf.sprintf "ifgoto(label%d)" l       
      
  let string_of_bytecodes word_arr code = String.concat " " (List.fold_left (fun acc el -> acc@[string_of_bytecode word_arr el]) [] code)
    let tag bc = snd 
      (List.fold_left (fun (i,acc) bc ->
			 match bc with
			   | Prefix   (opc,v)              ->  i+2, acc @ [i, bc]
			   | Prefix16 (opc,v)              ->  i+3, acc @ [i, bc]
			   | Prefix32 (opc,v)              ->  i+5, acc @ [i, bc]
			   | Opcode opc when opc >= 253    ->  i+2, acc @ [i, bc]
			   | Opcode opc                    ->  i+1, acc @ [i, bc] 
			   | Branch ofs                    ->  i+2, acc @ [i, bc]
			   | Branch0 ofs                   ->  i+2, acc @ [i, bc]
			   | Label l                       ->  i+0, acc @ [i, bc])
	 (0,[]) bc)

    let reduce_pass labels = 
      tag % 
	List.map (fun (t,op) ->
		    let emit_branch ind i =
		      let v = List.assoc i labels - t-1 in
			if v >= -127 && v <= 128 then
			  Prefix (ind, v)
			else(
			  Prefix16 (ind + 3,v)) in
		      match op with
			| Branch  i -> emit_branch 2 i
			| Branch0 i -> emit_branch 3 i
			| rest -> rest) % 
	List.filter (function _,Label _ -> false | _,_ -> true)

  let disassemble_word name word_arr lst =
    let rec pass0 ofs =
      let adv n = pass0 $ ofs+n in
	function
	  | []                                                  -> [],ofs
	  | a::i::xs      when a = 0 || a = 2 || a = 3 || a = 4 -> let bc, ofs' = adv 2 xs in (ofs, Prefix   (a, ext_sign i))          :: bc, ofs'
	  | a::b1::b2::xs when a = 5 || a = 6                   -> let bc, ofs' = adv 3 xs in (ofs, Prefix16 (a, ext_sign16 b1 b2))    :: bc, ofs'
	  | 1::b1::b2::b3::b4::xs                               -> let bc, ofs' = adv 5 xs in (ofs, Prefix32 (1, (dword b4 b3 b2 b1))) :: bc, ofs'
	  | 253::i::xs                                          -> let bc, ofs' = adv 2 xs in (ofs, Opcode (250 + i))                  :: bc, ofs'
	  | c::xs                                               -> let bc, ofs' = adv 1 xs in (ofs, Opcode c)                          :: bc, ofs'
    in
    let add k ass = try let _ = List.assoc k ass in ass with Not_found -> ass@[k,List.length ass] in
    let rec pass1' ass = 
      function
      | [] -> ass
      | (ofs, Prefix(opcode, offset))   :: xs when opcode = 2 || opcode = 3 -> 
	  (*Printf.printf "lab: %d %d\n" opcode offset;*)
	  let o = offset + ofs+1 in 
	    pass1' (add o ass) xs
      | (ofs, Prefix16(opcode, offset)) :: xs ->
	  (*Printf.printf "lab: %d %d\n" opcode offset;*)
	  let o = offset + ofs+2 in 
	    pass1' (add o ass) xs
      | _                               :: xs -> pass1' ass xs 
    in
  let pass1 = pass1' [] in
    let rec pass2 labels = 
      List.fold_left 
	(fun acc (index, bytecode) ->
	   match bytecode with
	     | Prefix(opcode, offset) when opcode = 2 || opcode = 3 -> 
		 let offset' = offset + index + 1 in
		 let lab = List.assoc offset' labels in
		   acc @ [index, if opcode = 2 then Branch lab else Branch0 lab]
	     | Prefix16(opcode, offset) when opcode = 5 || opcode = 6 -> 
		 let offset' = offset + index + 2 in
		 let lab = List.assoc offset' labels in
		   acc @ [index, if opcode = 5 then Branch lab else Branch0 lab]
	     | a -> acc@[index,a]) []
    in
    let insert_labels labels =
      List.fold_left 
	(fun acc (ofs,a) -> 
          try let l = (List.assoc ofs labels) in 
            acc @ [ofs,Label l] @ [ofs,a]
          with Not_found -> acc @ [ofs,a]) []
    in
	  
    let rec untag = function
      | [] -> []
      | (_,a)     ::xs ->           a::(untag xs) 
    in
    let rec rem_last = List.rev % List.tl % List.rev in
    match lst with
      | 255::xs -> Bytecode 
	  (let bc',ofs = (pass0 0 xs) in
	   let bc = bc' @ [ofs, Label 255] in
	   let lb = pass1 bc in
	     (*Printf.printf "Heyah!\n";*)
 	   let bc'' = snd % List.split % insert_labels lb $ pass2 lb bc in
	     rem_last bc'')
      | s::xs   -> Core (Array.of_list xs)
      | []      -> Core (Array.make 0 0)
	  
    let make_word i o word_arr name code =
      { name   = name;
        index  = i  ;
	offset = o  ;
	code   = disassemble_word name word_arr code;
	used   = 0;
	prefix = i <= 6;
      }

    let rec traverse0 words word =
      match word.code with
	| Core a -> word.used <- 1
	| Bytecode b -> 
	    word.used <- 1; 
	    List.iter
	    (fun x ->
	       match bytecode_id' x with
		 | Some id ->
		     (let word' = words.(id) in
			traverse0 words word')
		 |  None -> ()
	    ) b

    let rec traverse_count words =
      Array.iter (fun w -> match w.code with
		   | Core a -> ()
		   | Bytecode b -> 
		       List.iter
			 (fun x ->
			    match bytecode_id' x with
			      | Some id ->
				  (let word' = words.(id) in
				     (if word'.used >= 1 then word'.used <- word'.used + 1 else ()))
			      |  None -> ()) b) words
	
    let traverse words word =
      traverse0 words word;
      traverse_count words;
      Array.iter (fun w -> if w.used > 0 then w.used <- w.used - 1 else ()) words;
      word.used <- 1



    let words (code_sec,name_sec) =
      let word_image = Image.to_list code_sec in
      let rec offsets lst =
	let rec drop_bytecode n = function
	  | [] -> [],n
	  | 254::_                                -> [],n
	  | x::_::_::_::_::xs when x = 1          -> drop_bytecode (n+5) xs
	  | x::_::xs          when x < 5          -> drop_bytecode (n+2) xs
	  | x::_::_::xs       when x = 5 || x = 6 -> drop_bytecode (n+3) xs
	  | x::_::xs          when x = 253        -> drop_bytecode (n+2) xs
	  | 255::xs as l                          -> l,n
	  | x::xs                                 -> drop_bytecode (n+1) xs in
	let next = drop_bytecode 0 in
	let rec offsets' prev offset = function
	  | []                -> []
	  | 254::_            -> []
          | 255::xs           -> let xs',n = next xs in (offset, n+1)::(offsets' true  (offset+n+1) xs')
	  | n::xs             ->                        (offset, n+1)::(offsets' false (offset+n+1) (drop n xs)) in
	  offsets' false 0 lst in
      let ofs = offsets word_image in

      let name = function
	| i ->
	    implode (List.rev (Array.fold_left
				 (fun acc x ->
				    match x with
				      | 0 -> acc
				      | _ -> (char_of_int x)::acc) [] (Array.sub name_sec.Image.image (i*32) 32)))
      in
	
      let names =
	let rec names' i =
	  if i * 32 + 32 <= name_sec.Image.len then
	    let n = name i in
(*	      Printf.printf "Name:: %d %s\n" i n; *)
	      if n = "" then names' (i+1) else n::(names' (i+1))
	  else [] in
	  names' 0
      in
	(*Printf.printf "n:%d, o:%d\n" (List.length ofs) (List.length names);*)
      let ofs = List.rev (drop (List.length ofs - List.length names) (List.rev ofs)) in
      let names = List.rev (drop (List.length names - List.length ofs) (List.rev names)) in
	(*Printf.printf "n:%d, o:%d\n" (List.length ofs) (List.length names);*)
      let words_pre = List.combine ofs names in
      let words_list = List.rev (snd (List.fold_left
					  (fun (i,acc) ((o,l),name) ->
					     let ar = Array.sub code_sec.Image.image o l in
					     let code = Array.to_list ar in
					       (i+1), (make_word i o (Array.of_list names) name code)::acc
					  )
					  (0,[]) words_pre)) in
	let words_ar = Array.of_list words_list in
	let last_word = words_ar.(Array.length words_ar-1) in
	  last_word.used <- 1;
	  traverse words_ar last_word;
	  words_list
	
  let to_string w =
      Printf.sprintf "Name: %.16s\tOffset: %d\tLen: %d\tIndex: %d\tUsed: %d" w.name w.offset 0 w.index w.used
    
  let dw dword =
    let b4 = Ni.to_int (Ni.logand (Ni.shift_right_logical dword 24) (Ni.of_int 255)) in
    let b3 = Ni.to_int (Ni.logand (Ni.shift_right_logical dword 16) (Ni.of_int 255)) in
    let b2 = Ni.to_int (Ni.logand (Ni.shift_right_logical dword 8)  (Ni.of_int 255)) in
    let b1 = Ni.to_int (Ni.logand dword (Ni.of_int 255)) in
      b1::b2::b3::b4::[]

  let wd word =
    let b2 = Ni.to_int (Ni.logand (Ni.shift_right_logical word 8)  (Ni.of_int 255)) in
    let b1 = Ni.to_int (Ni.logand word (Ni.of_int 255)) in
      [b1;b2]


    let collect_labels bc = 
      List.fold_left (fun acc (t, bc) ->
			match bc with
			  | Label l -> acc@[(l,t)]
			  | _ -> acc) [] bc

    let rec emit_bytecode bc =
      let pass0 = tag bc in
      let labels = collect_labels pass0 in
	List.fold_left (fun acc (t,op) ->
			  (*let emit_branch ind i =
			    let v = List.assoc i labels - t-1 in
			    if v  >= -127 && v <= 128 then
			      [ind;v]
			    else
			      [ind+3] @ (wd%Int32.of_int $ v)
			  in
			  *)
			  match op with
			    | Prefix   (i,v)         -> acc @ [i;v] 
			    | Prefix16 (i,v)         -> acc @ [i] @ (wd%Int32.of_int $ v)
			    | Prefix32 (i,v)         -> acc @ [i] @ (dw v)
			    | Opcode i when i >= 253 -> acc @ [253; i-253]
			    | Opcode i               -> acc @ [i]
			    | Label i                -> acc
(*      			    | Branch i               -> acc @ emit_branch 2 i
			    | Branch0 i              -> acc @ emit_branch 3 i
				    
*)
			    | _ -> failwith "emit_bytecode"
		       ) [] % reduce_pass labels $ pass0
      	  
  
  let emit words name_section section =
    let emit_names w sec =
      let explode str =
	let rec loop i acc =
	  if i < 0 then acc else
	    loop (i-1) ((String.get str i)::acc) in
	  loop ((String.length str)-1) []
      in
	ignore(List.fold_left
		 (fun (i,ofs) w ->
		    let str = explode w.name in
		    let arr = Array.make 32 0 in
		      ignore(List.fold_left (fun i x -> arr.(i) <- int_of_char x; i+1) 0 str);
		      if i = 253 then
			let arr' = Array.make (3*32) 0 in
			  Array.blit arr' 0 sec.Image.image (32*253) (3*32); 
			  Array.blit arr 0 sec.Image.image (32*256) 32;
			  257,3
		      else
			(Array.blit arr 0 sec.Image.image (32*(w.index+ofs)) 32; (i+1,ofs))) (0,0) w)
    in
    let rec emit_words i =
      function
	| [] -> i
	| x::xs ->
	    (match x.code with
	       | Core im -> 
		   section.Image.image.(i) <- Array.length im;
		   Array.blit im 0 section.Image.image (i+1) (Array.length im);
		   emit_words (i+1+(Array.length im)) xs
	       | Bytecode bc ->
		   let im = Array.of_list (emit_bytecode bc) 
		   in
		     section.Image.image.(i) <- 255;
		     Array.blit im 0 section.Image.image (i+1) (Array.length im);
		     emit_words (i+1+(Array.length im)) xs) 
    in
    let i = emit_words 0 words in
      emit_names words name_section; 
      (*      Printf.printf "%d\n\n" i; *)
      section.Image.image.(i) <- 254
	
  let rec loop ok f v = if ok v then v else loop ok f (f v)
    
  let no_labels = List.fold_left (fun i x -> 
				    match x with
				      | Label _ -> i+1 
				      | a -> i) 0
  let ins i w = 
    match w.code with Bytecode b -> 
      List.map (function
		  | Branch0 c -> Branch0 (c + i)
		  | Branch c  -> Branch (c + i)
		  | Label c -> Label (c+i)
		  | a -> a 
	       ) b, i+no_labels b
      | Core _ -> [],0
   
  let inline_single inlined word  =
    match word.code with 
      | Bytecode b -> 
	  let rec loop oi =
	    function 
	      | x::xs -> (match bytecode_id' x with 
			    | Some id -> if id = inlined.index then 
				let l,oi' = ins oi inlined in 
				  l @ loop oi' xs else x :: (loop oi xs)
			    | None    -> x :: (loop oi xs)
			 )
	      | [] -> [] 
	  in
	  let b = loop (no_labels b) b in
	    { word with code=Bytecode b }
      | b -> word
    

  let rec inline words  = 
    let used_once = List.filter (fun w -> w.used = 1 && match w.code with Bytecode _ -> true | Core _ -> false ) words in
      List.fold_left (fun acc x -> List.map (inline_single x) acc) words used_once

  let optimise' words_list =
    let words_ar = Array.of_list words_list in
    let used = Array.fold_left (fun acc w -> if w.used <> 0 || w.index <= 6 then w::acc else acc) [] words_ar in
      print_endline "------1";
      let used = List.rev (fst (List.fold_right (fun w (acc,i) -> (i,w)::acc,i+1) used ([],0))) in
	print_endline "------2";
	
	let replace_opcode new_op = function
	  | Prefix   (_,v) -> Prefix   (new_op,v)
	  | Prefix16 (_,v) -> Prefix16 (new_op,v)
	  | Prefix32 (_,v) -> Prefix32 (new_op,v)
	  | Opcode    _    -> Opcode new_op
	  | a -> a in
	  
	let rec swap_ids words =
	  let rec loop = function
	    | [] -> []
	    | w::ws ->
		match bytecode_id w with
		  | Some id ->
			 let i,w' = List.find (fun (i',w') -> id = w'.index) words 
		      in
			   (replace_opcode i w)::(loop ws)
		  | None -> w::(loop ws) in
	    
	  let words' = List.map
	    (fun (i,w) ->
	       match w.code with
		 | Core _ -> i,w
		 | Bytecode b -> i, { w with code=Bytecode (loop b) } ) words in
	    
	  let words' = List.map
	    (fun  (i,w) ->
	       w.index <- i;
	       words_ar.(i) <- w; w) words' 
	  in
	    words'
	in

	let prefix,non_prefix = List.partition (fun (i,w) -> w.prefix) used in
	  
	let spacer =
	  let rec loop = function
	      i when i <= 6 -> (i,{ name="#spacer#"; index = i; offset=0; code=Core [||]; used=1; prefix=true})::(loop (i+1)) | _ -> [] in
	    loop (List.length prefix)
	in
	let ofs = 7-List.length prefix in
	let used' = prefix @ spacer @ (List.map (fun (i,w) -> (i+ofs,w))) non_prefix in
	let u = swap_ids used' in
	  u
	
  let tag_unused ws =
    match List.rev ws with
      | l::ws' -> (let ws'' = List.map (fun w -> if w.used = 1 && match w.code with Bytecode _ -> true | Core _ -> false then {w with used=0} else w ) (List.rev ws') in
      ws''@[l])
      | _ -> failwith "tag_unused"

  let optimise words = 
    let process = inline % inline % inline % inline % inline % inline % inline % inline % inline % inline % inline % inline % optimise' in
(*    let process =  optimise' in *)
    let w = process words in 
    let wa = Array.of_list w in
    let last_word = wa.(Array.length wa-1) in
      last_word.used <- 1;
      traverse wa last_word;
      optimise' $ w
	  
end
module FourkImage = struct

  let words image =
    let name_sec = Image.find_section image "name" in
    let word_sec = Image.find_section image "words" in
      Words.words (word_sec,name_sec)

    let stripped_sections =  ["interpret";"name";"dsptch";"semantic";] 
(*    let stripped_sections =  [] *)
(* 92 *)
  let strip image =
  (*  let secs = List.fold_left (fun acc i -> List.filter (fun x -> not (i = x.Image.name)) acc) image.Image.sections removed_sections in *)
    List.iter (fun x -> if (List.mem x.Image.name stripped_sections) then Image.zero x ) image.Image.sections;
      image
(*
      { image with Image.sections = secs }
*)

  let copied_sections = ["words";"name";"semantic";"there"]
  let std_sections = ["dict"; "interpret"; "dsptch"; "default"; "words";"name";"semantic";"there"]

  let link base_image image word_count =
    let dict_section = Image.find_section base_image "dict" in
    let there_section = Image.find_section base_image "there" in
      Array.fill dict_section.Image.image 0 5 0x90; 
      BinaryArray.set_dword dict_section.Image.image 6 word_count;
      
      List.iter (fun nm ->
		   let src = Image.find_section image nm in
		   let dst = Image.find_section base_image nm in
		      Image.copy src dst ) copied_sections;
      let cp src dst i1 i2 l = Array.blit src i1 dst i2 l in
	List.iter (fun sec -> 
		  (*		     Printf.printf "sec: %s\n" sec.Image.name; *)
		     if not (List.mem sec.Image.name std_sections) then
		       (
		       (*			 Printf.printf "SECTION!!%s %d %d %d\n" sec.Image.name sec.Image.offset there_section.Image.offset there_section.Image.len ; *)
			 cp sec.Image.image there_section.Image.image 0 (sec.Image.offset - there_section.Image.offset + dict_section.Image.offset-4) sec.Image.len;
		(*	   Printf.printf "whoa\n"; *)
		       ))  image.Image.sections;
(*      Image.relocate (image, ref_image) (Image.find_section base_image "dict") (Image.find_section base_image "interpret"); *)
      ()

  let sections image =
    let there = Image.find_section image "there" in
    let number = Int32.to_int $ BinaryArray.get_dword there.Image.image 0 in
    let rec section_name' acc i = 
      let ch = there.Image.image.(i) in
      if ch <> 0 then
	section_name' ((char_of_int ch)::acc) $ i + 1
      else
	implode $ List.rev acc 
    in
    let rec loop acc ofs i =
      if i < number then
	let nm = section_name' [] ofs in loop (nm::acc) (ofs+32) $ i + 1
      else List.rev acc 
    in
      loop [] 4 0
	
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
			    Array.iter (fun x -> let x' = char_of_int x in Printf.printf "%c" x') s.Image.image)
	       ]), "Dump given section";
      "-sections", String (fun nm ->
			     let image = Image.load nm in
			       Image.print_sections image
			  ),
      "List sections";
      "-opt", String (fun x ->
			let image = Image.load x in
			let words = Words.optimise (FourkImage.words image) in
			let sec = Image.find_section image "words" in
			let nsec = Image.find_section image "name" in
			  Image.zero sec; 
			  Image.zero nsec; 
			  Words.emit words nsec sec; 
			  Image.save image x ), "Optimise";
		   
      "-link", (let image_name = ref "" in
	(*	let ref_name = ref "" in *)
		  Tuple [Set_string image_name;
			 String (fun core_name ->
				   let base_image = Image.load core_name in
				   let image = Image.load !image_name in
				   let words = Words.optimise (FourkImage.words image) in
				   let sec = Image.find_section image "words" in
				   let nsec = Image.find_section image "name" in
				     Image.zero sec; 
				     Image.zero nsec; 
				     Words.emit words nsec sec; 
				     FourkImage.link base_image image (Int32.of_int (List.length words));
				     Image.save base_image core_name
)]
	       ),
      "Link with fourk engine";
      "-strip", String
	(fun nm ->
	   let image = Image.load nm in
	   let image2 = FourkImage.strip image in
	     Image.save image2 nm
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
(*						Words.Bytecode lst' -> Printf.printf ": %s %s ;\n" x.Words.name (Words.string_of_bytecodes (Array.map (fun el -> el.Words.name) wordsa) lst') *)

					      | Words.Bytecode lst' -> 
						  begin
						    let x' = Words.disassemble_word x.Words.name (Array.map (fun el -> el.Words.name) wordsa) (255::(Words.emit_bytecode lst')) in

						    match x' with
						      | Words.Bytecode lst -> 
							  Printf.printf ": %s %s ;\n" x.Words.name (Words.string_of_bytecodes (Array.map (fun el -> el.Words.name) wordsa) lst)
						      | _ -> failwith "-disass"
						  end

					      | _ -> ()) words;
			     Printf.printf "Sections:\n%s\n" $ (String.concat "\n" $ FourkImage.sections image) 
			),
      
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
			  let lst = (List.map (fun ((n,o),(_,r)) -> n,Image.relocs r o) pre) in
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
			  let lst = (List.map (fun (o,r) -> o.Image.name,Image.relocs o.Image.image r.Image.image) pre) in
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
				  | Words.Bytecode lst -> Printf.printf ": %s %s ;\n" x.Words.name (Words.string_of_bytecodes (Array.map (fun el -> el.Words.name) wordsa) lst)
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

let usage_text = "image4k <options> <file>"

  let process_file nm = ()
  let _ =
  if Array.length Sys.argv > 1 then
    parse Options.options process_file usage_text
  else usage Options.options usage_text
;;

