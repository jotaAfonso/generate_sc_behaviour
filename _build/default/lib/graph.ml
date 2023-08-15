open Model

let allpaths = ref []

type segment_impl =
  | ThunkList

let rec print_paths (x : string list list) = 
  match x with 
    [] -> ()
    | x :: xs -> Printf.printf "Path : %s\n" @@ String.concat " " x; print_paths xs 
;;

let rec print_tuple (x : (string * string) list) = 
  match x with 
    [] -> ()
    | (_,y) :: xs -> Printf.printf "Path tuple : %s\n" y; print_tuple xs 
;;
module type ARG = sig
  include Segments.OrderedMonoid
  include Segments.Trie.WORD with type t := t
end

module type S =
  functor (W : ARG) -> (Segments.S with type elt = W.t)

let get_impl_mod : segment_impl -> (module S) = let open Segments in function
  | ThunkList -> (module ThunkList)

let subWord p wordl t i = 
  String.sub p (String.length p - (wordl * t) - i) wordl
;;

let rec uniquepathindex p s i : bool =
  let w = String.sub p (String.length p - s) s in 
  if (String.length w) * 3 <= ((String.length p) - i) then 
    let wordl = String.length w in 
    if Bool.(&&) (String.equal (subWord p wordl 1 i) (subWord p wordl 3 i)) (String.equal (subWord p wordl 1 i) (subWord p wordl 2 i))   
      then false 
      else Bool.(&&) true @@ uniquepathindex p s (i + 1)
  else true

let rec uniquepathsize p s i : bool =
  let w = String.sub p (String.length p - s) s in 
  if (String.length w) * 3 <= (String.length p) then 
    let wordl = String.length w in 
    if Bool.(&&) (String.equal (subWord p wordl 1 i) (subWord p wordl 3 i )) (String.equal (subWord p wordl 1 i) (subWord p wordl 2 i))  
      then false 
      else Bool.(&&) (uniquepathindex p s i) @@ uniquepathsize p (s + 1) i
  else 
    true  

let rec dfs (_list : (string * (string * string) list) list) _src (_path : string list) counter =
  if counter < 20 then
    let module M = (val get_impl_mod ThunkList) in
    let module S = M(Word.String) in
    let module A = Regenerate.Make (Word.String) (S) in
    
    let local_path = String.concat "" _path in
    let check = uniquepathsize local_path 1 0 in
    
    try
      if check then 
        allpaths := !allpaths @ [_path];
      let (_, filter) = List.find (fun (a,_ ) -> String.equal a _src) _list in 
      List.iter (fun (_, y) -> let npath = _path @ [y] in dfs _list y npath (counter + 1)) filter;
    with
      | Not_found -> ()
;;

let find_all_paths (list : (string * (string * string) list) list) src =
  let path = src :: [] in
  dfs list src path 0 ;
  !allpaths;
;;

let generate_graph (_ops : operation list) = 
  let edges = List.map (fun (x : operation) -> (x.requiredState, [x.operationlabel, x.resultState])) _ops in 
  let result = List.map (fun (x,_) -> x, List.concat @@ List.map (fun (_, b) -> b) @@ List.filter (fun (z,_) -> String.equal z x) edges) edges in
  let uniq_cons x xs = if List.mem x xs then xs else x :: xs in 
  List.fold_right uniq_cons result []
;;

