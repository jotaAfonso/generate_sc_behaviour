open Model
open Model.Contract

let contains s1 s2 =
  let re = Str.regexp_string s2
  in
    try ignore (Str.search_forward re s1 0); true
    with Not_found -> false
;;

let read_file filename = 
  let lines = ref [] in
  let chan = open_in filename in
  try
    while true; do
      lines := input_line chan :: !lines
    done; !lines
  with End_of_file ->
    close_in chan;
    List.rev !lines
;;

let rec extractStates (lines : string list) flag : string list =
  match (lines , flag) with
    [] , _ -> []
    | x :: xs, false -> if Bool.(&&) (contains x "data") (contains x "StateType") 
      then [String.trim x] @ extractStates xs true else [] @ extractStates xs false
    | x :: xs, true -> if contains x "deriving" 
      then [] else [String.trim x] @ extractStates xs true
;;

let rec extractDeploy (lines : string list) flag : string list =
  match (lines , flag) with
    [] , _ -> []
    | x :: xs, false -> if contains x "template" 
      then [String.trim x] @ extractDeploy xs true else extractDeploy xs false
    | x :: xs, true -> if Bool.(||) (contains x "where") (contains x "choice") 
      then [] else [String.trim x] @ extractDeploy xs true
;;

let rec getTemplateLabel lines : string = 
  match lines with
   [] -> ""
  | x :: xs -> if contains x "template" 
      then List.hd (Str.split (Str.regexp "template") x)
      else getTemplateLabel xs
;;

let rec getParams lines : Contract.parameter list = 
  match lines with
   [] -> []
  | x :: xs -> if contains x ":" 
      then let split_param = (x |> String.split_on_char ':') in 
        let result : Contract.parameter = { labelOfParam = (String.trim @@ List.nth split_param 0); typeLabel = String.trim @@ List.nth split_param 1 } in
        [ result ] @ getParams xs 
      else getParams xs
;;
 
let rec extractParametersOfMethods lines =
  match lines with 
    [] -> []
    | x :: xs -> if contains x ":"  
      then let split_param = (x |> String.split_on_char ':') in 
        let result : Contract.parameter = { labelOfParam = (String.trim @@ List.nth split_param 0); typeLabel = String.trim @@ List.nth split_param 1 } in
        if contains x "controller" 
          then [ result ]
          else [ result ] @ extractParametersOfMethods xs
        else if contains x "controller" 
          then []
          else extractParametersOfMethods xs


let treatStates lines =
  (*Extracts states*)
  let eStates = extractStates lines false in
  
  (*Treats states, organizes from into one line and splits on =, the start of the states values*)
  let lineStates = (String.concat " " eStates) 
    |> String.split_on_char '=' |> List.filter (fun s -> s <> "") in

  (*Treats states, splits string into each trimmed state*)(*Treats states*)
  List.map (fun (x:string) -> String.trim x) ((List.nth lineStates 1) |> String.split_on_char '|')
;;

(*Extracts constructor*)
let treatDeploy lines : Contract.template =
  let eDeploy = (extractDeploy lines false) |> List.filter (fun s -> s <> "") in 
  let lTLabel = getTemplateLabel eDeploy in 
  let lParams = getParams eDeploy in 
  { templateLabel = lTLabel; parametersInput = lParams; initialState = "" }
;;

let extractMethodLabel line =
  let splitChoice = (Str.split (Str.regexp "choice") (List.nth (line |> String.split_on_char ':') 0)) in 
  match (List.length splitChoice) with
    1 -> String.trim (List.nth splitChoice 0)
    | _ -> String.trim (List.nth splitChoice 1)
;;

let rec extractResultState lines =
  match lines with 
    [] -> ""
    | x :: xs -> if contains x "state" then String.trim (List.nth (x |> String.split_on_char '=') 1)
      else extractResultState xs
;;

let rec extractPostConditionsMethod lines =
  match lines with
    [] -> []
    | x :: xs -> 
      if (contains x "=")
      then [String.trim x] @ extractPostConditionsMethod xs
      else if (contains x "choice")
        then []
      else [] @ extractPostConditionsMethod xs
;;

let extractRequiredState line : string =
  let splitLine = line |> String.split_on_char '=' in 
  let first = List.nth splitLine 0 in 
  let second = List.nth splitLine 2 in
  if contains first "state" 
    then let sR = (second |> String.split_on_char '=') in 
      match List.length sR with
        1 -> String.trim (Str.(global_replace (regexp ")") "" (List.nth sR 0)))
        | _ -> String.trim (Str.(global_replace (regexp ")") "" (List.nth sR 1)))
    else (* when state value is on the left side *)
      ""
;; 

let extractPreConditionsMethod line preC =
  if (contains line "assertMsg") 
    then let splitChoice = (Str.split (Str.regexp "\"") line) in 
      [String.trim (List.nth splitChoice 2)] @ preC   
    else let splitChoice = (Str.split (Str.regexp "assert") line) in
      [String.trim (List.nth splitChoice 1)] @ preC  

let rec extractMethods (lines : string list) flag (operation : Contract.operation) (deploy : Contract.template) : Contract.operation list=
  match (lines , flag) with
    [] , _ -> []
    | x :: xs, false -> if contains x "choice" 
      then extractMethods xs true { operation with operationlabel = extractMethodLabel x; parameters = extractParametersOfMethods xs} deploy 
      else extractMethods xs false operation deploy
    | x :: xs, true -> if (contains x "assert") 
      then 
        if (contains x "state") 
          then extractMethods xs true { operation with requiredState = extractRequiredState x} deploy 
          else if (contains x "assert") 
            then extractMethods xs true { operation with preconditions = extractPreConditionsMethod x operation.preconditions} deploy 
            else extractMethods xs true operation deploy 
      else 
        if Bool.(&&) (contains x "create") (Bool.(||) (contains x deploy.templateLabel) (contains x "this")) 
          then [{ operation with resultState = extractResultState xs; postconditions = List.filter (fun x -> Bool.not @@ contains x "state") (extractPostConditionsMethod xs)}] @ extractMethods xs false { operationlabel = ""; resultState = ""; requiredState = ""; parameters = []; preconditions = []; postconditions = []} deploy 
          else extractMethods xs true operation deploy
;;