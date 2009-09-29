open Image
type t = { length:int; name:string }

let list_words name_section dict_section =
  let bytes = get_bytes section in
  let loop acc = 
    
  let loop i len = function
    | [] -> ()
    | -1::xs -> Printf.printf "Name: %s Len: %d\n" 
  
