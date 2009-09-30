open Image
type t = { offset:int; length:int; name:string }

let list_words name_section (*dict_section*) =
(*  let bytes = Section.get_bytes dict_section in*)
  let names = Section.to_list name_section in
  let get_string i = 
    let lst = 
      List.rev
	(List.fold_left 
	   (fun acc x -> match x with 0 -> acc | _ -> (char_of_int x)::acc)
	   (Array.sub name_section (i*32) 32)) in
    let str = String.create (List.length lst) in
      (List.fold_left (fun x (i,acc) -> str.[i] <- x; i+1) lst);
      str
  in
  let no = Array.length names / 32 in
    for i = 0 to no - 1 do
      Printf.printf "Name: %s Len: %d\n" (get_string i) i
    done
		      
(*  let loop i len = function
    | [] -> ()
    | -1::xs -> Printf.printf "Name: %s Len: %d\n" 
*)
