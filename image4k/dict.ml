(* FourK - Concatenative, stack based, Forth like language optimised for  *)
(*        non-interactive 4KB size demoscene presentations. *)

(* Copyright (C) 2009, 2010 Wojciech Meyer, Josef P. Bernhart *)

(* This program is free software: you can redistribute it and/or modify *)
(* it under the terms of the GNU General Public License as published by *)
(* the Free Software Foundation, either version 3 of the License, or *)
(* (at your option) any later version. *)

(* This program is distributed in the hope that it will be useful, *)
(* but WITHOUT ANY WARRANTY; without even the implied warranty of *)
(* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the *)
(* GNU General Public License for more details. *)

(* You should have received a copy of the GNU General Public License *)
(* along with this program.  If not, see <http://www.gnu.org/licenses/>. *)
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
