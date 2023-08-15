(*
let rec print_methods (ls : operation list) = 
  match ls with
    [] -> ()
    | x :: xs -> Printf.printf "%s\n" x.label; Printf.printf "%s\n" x.requiredState; Printf.printf "%s\n" x.resultState; print_methods xs
;;

*)
let rec _print_list ls = 
  match ls with
    [] -> ()
    | x :: xs -> Printf.printf "to - %s\n" x; _print_list xs
;;

let rec print_op (ls : (string * string) list) =
  match ls with
    [] -> ()
    | (x,y) :: xs -> Printf.printf "edge1 - %s\n" x; Printf.printf "edge2 - %s\n" y; print_op xs
;;

let rec _print_edge (x : (string * (string * string) list) list) = 
  match x with
    [] -> ()
    | (x,y) :: xs -> Printf.printf "origin - %s\n" x; print_op y; _print_edge xs
;;

let rec print_paths (x : string list list) = 
  match x with 
    [] -> ()
    | x :: xs -> Printf.printf "Possible positive path: %s\n" @@ String.concat " " x; print_paths xs 
;;


open Lib_generate

(*Gets every line from a file*)
let lines = ExtractSC.read_file "/home/camel/Desktop/generate_sc_behaviour/test.txt";;

let _states = ExtractSC.treatStates lines;;
let deploy = ExtractSC.treatDeploy lines ;;

let methods = ExtractSC.extractMethods lines false { operationlabel = ""; resultState = ""; requiredState = ""} deploy;;

(*test
let teste : Model.operation = { operationlabel = "makeOffer"; requiredState = "0"; resultState = "1"};;
let test2 : Model.operation = { operationlabel = "dmakeOffer"; requiredState = "0"; resultState = "2"};;
let test3 : Model.operation = { operationlabel = "pmakeOffer"; requiredState = "1"; resultState = "3"};;
let test4 : Model.operation = { operationlabel = "pmakeOffer"; requiredState = "2"; resultState = "3"};;

let _testG : Model.operation list = teste :: test2 :: test3 :: test4 :: [];;
*)
let graph = Graph.generate_graph methods;;

let err_msg = function
    | `Parse_error -> `Msg "Incorrect regular expression"
    | `Not_supported -> `Msg "Unsupported syntax"

let _parser s = 
  match Parsing.parse s with
   Ok x -> Ok x 
   | Error e -> Error (err_msg e)
;;

let paths = Graph.find_all_paths graph "I";;

print_paths paths;;

Printf.printf "File Test executed.\n";;