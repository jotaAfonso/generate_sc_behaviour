open Lib_generate.Model.FiniteAutomaton
open Lib_generate.Model.Contract
open Lib_generate.Parsing
open Lib_generate.ExtractSC
open Lib_generate
(*
open Z3
open Z3.Expr
open Z3.Arithmetic
open Z3.Arithmetic.Real
open Z3.Goal
open Z3.Solver
*)
open Automata.Types_j
open Str

let _counter = ref 0;;

let rec changeRegexWords (regex:string) (alphabet: string list) =
  match alphabet with 
    [] -> regex
    | w :: xs -> changeRegexWords (Str.global_replace (Str.regexp w) ("(" ^ w ^ ")") regex) xs 

let rec changeRegexSymbols (regex:string) (alphabet: string list) =
  match alphabet with 
    [] -> regex
    | "?" :: xs -> changeRegexSymbols (Str.global_replace (Str.regexp "?") ("{0,1}") regex) xs 
    | "+" :: xs -> changeRegexSymbols (Str.global_replace (Str.regexp "+") ("{1,2}") regex) xs
    | "*" :: xs -> changeRegexSymbols (Str.global_replace (Str.regexp "*") ("{0,2}") regex) xs
    | _ :: xs -> changeRegexSymbols regex xs


let _regex automaton= 
  let r = get_regex automaton in
  let alphabet_regex = changeRegexWords r automaton.alphabet in
  
  let symbols_list = ["?";"+";"*"] in
  let result = changeRegexSymbols alphabet_regex symbols_list in
  
  result
  ;;

let gen_re regex_string = 
  let sigma = (CCString.of_list @@ CCOpt.get_exn @@ Regex.enumerate ' ' '~') ^ "$" in
  let regex = Result.get_ok (parse regex_string) in
  let result = Regen._print_allv2 sigma regex (None) None in 
  let (pos, _) = result in 
  let result = Iter.to_list pos in
  List.map (fun s -> ((global_replace (regexp "ε") "" s))) result
;;


let path_analise_word path w =
  if (Str.string_partial_match (Str.regexp path) w 0) 
    then (w, (Str.replace_first (Str.regexp w) "" path))
    else ("","")

(* replace_first *)
let rec _path_to_list path alpha alpha_values =
  match alpha with
    [] -> []
    | x :: xs -> 
      if (String.length path) <> 0 
      then
        let result_l = path_analise_word path x in 
        match result_l with 
          (x, y) when x <> "" -> [x] @ _path_to_list y alpha_values alpha_values
          | (_, _) -> _path_to_list path xs alpha_values 
      else
        []

let _is_string_regex regex substring =
  Str.string_match (Str.regexp regex) substring 0 

let rec _remove_first_three_elements l count =
  match count, l with
     _, [] -> []
    | 2, _ :: xs -> xs
    | _, _ :: xs -> _remove_first_three_elements xs (count + 1)
      
(*

let rec createConst ctx (params : parameter list) =
  match params with 
     [] -> []
    | p :: xs -> [p.labelOfParam, mk_const_s ctx p.labelOfParam] @ createConst ctx xs

let rec createAssertion ctx assertions =
  match assertions with 
    [] -> []
    | a :: xs -> 
      let a_to_list = (String.split_on_char ' ' a) in
      let first_exp a b c =
        let a_value = 
          if is_string_regex "[0-9]+$" a 
            then mk_numeral_string ctx a (Integer.mk_sort ctx)
          else (mk_const_s ctx a) in
        let c_value = 
          if is_string_regex "[0-9]+$" c 
            then mk_numeral_string ctx c (Integer.mk_sort ctx)
          else (mk_const_s ctx c) in
        match b with 
          "<" -> [(Arithmetic.mk_lt ctx a_value c_value)] 
          |"<=" -> [(Arithmetic.mk_le ctx a_value c_value)] 
          |">" -> [(Arithmetic.mk_gt ctx a_value c_value)] 
          |">=" -> [(Arithmetic.mk_ge ctx a_value c_value)] 
          |"=" -> [(Boolean.mk_eq ctx a_value c_value)] 
          |"==" -> [(Boolean.mk_eq ctx a_value c_value)] 
          |"!=" -> [(Boolean.mk_not ctx (Boolean.mk_eq ctx a_value c_value))] 
          |"/" -> [(Arithmetic.mk_div ctx a_value c_value)]
          |"*" -> [(Arithmetic.mk_mul  ctx [a_value; c_value])] 
          |"-" -> [(Arithmetic.mk_sub ctx [a_value; c_value])] 
          | _ -> [(Arithmetic.mk_add ctx [a_value; c_value])]
      in
      let fexpr = first_exp (List.nth a_to_list 0) (List.nth a_to_list 1) (List.nth a_to_list 2) in
      let assert_clean = remove_first_three_elements a_to_list 0 in
      let rec cycle l p =
        match l with
          [] -> [p]
          | _ :: [] -> []
          | a :: b :: ys -> 
            let b_value = 
              if is_string_regex "[0-9]+$" b 
                then mk_numeral_string ctx b (Integer.mk_sort ctx)
              else (mk_const_s ctx b) in
            match a with 
              "<" -> let expr = (Arithmetic.mk_lt ctx p b_value) in [expr] @ cycle ys expr 
              |"<=" -> let expr = (Arithmetic.mk_le ctx p b_value) in [expr] @ cycle ys expr 
              |">" -> let expr = (Arithmetic.mk_gt ctx p b_value) in [expr] @ cycle ys expr 
              |">=" -> let expr = (Arithmetic.mk_ge ctx p b_value) in [expr] @ cycle ys expr 
              |"=" -> let expr = (Boolean.mk_eq ctx p b_value) in [expr] @ cycle ys expr 
              |"==" -> let expr = (Boolean.mk_eq ctx p b_value) in [expr] @ cycle ys expr 
              |"!=" -> let expr = (Boolean.mk_not ctx (Boolean.mk_eq ctx p b_value)) in [expr] @ cycle ys expr 
              |"/" -> let expr = (Arithmetic.mk_div ctx p b_value) in [expr] @ cycle ys expr 
              |"*" -> let expr = (Arithmetic.mk_mul  ctx [p; b_value]) in [expr] @ cycle ys expr 
              |"-" -> let expr = (Arithmetic.mk_sub ctx [p; b_value]) in [expr] @ cycle ys expr 
              | _ -> let expr = (Arithmetic.mk_add ctx [p; b_value]) in [expr] @ cycle ys expr   
            in
        let assert_expressions = cycle assert_clean (List.hd fexpr) in
        assert_expressions @ createAssertion ctx xs
;;
*)

(*

let rec addExpressionsOfEachMethod ctx path (regexData : regexwithassertions) =
  match path with
    [] -> []
    | x :: xs -> 
      let operation = List.hd @@ List.filter (fun y -> String.equal x y.operationlabel) regexData.operations in
      let _exp_pre_cond = createAssertion ctx operation.preconditions in
      let _exp_post_cond = createAssertion ctx operation.postconditions in
      let result = _exp_pre_cond @ _exp_post_cond in
      result @ addExpressionsOfEachMethod ctx xs regexData

let rec createDeployPartyScript oc paramList =
  match paramList with
    [] -> ()
    | x :: xs -> if (String.equal "Party" x.typeLabel) then
       Printf.fprintf oc "%s = alice\n" x.labelOfParam; createDeployPartyScript oc xs

let rec createDeployStateScript oc paramList initS =
match paramList with
  [] -> ()
  | x :: xs -> if (String.equal "state" x.labelOfParam) then
      Printf.fprintf oc "state = %s\n" initS; createDeployStateScript oc xs initS

let rec createDeployRestScript oc paramList model (_input_var : (string * expr) list) =
  match paramList with
    [] -> ()
    | x :: xs -> if ((&&) (not (String.equal "Party" x.typeLabel)) (not (String.equal "state" x.labelOfParam)) ) then
      let varz3 = snd @@ List.hd @@ List.filter (fun (a, _) ->  String.equal a x.labelOfParam) _input_var in 
      let x_value = Model.get_const_interp_e model varz3 in
      Printf.fprintf oc "      %s = " x.labelOfParam;
      Printf.fprintf oc "      %s\n" (Integer.numeral_to_string (Option.get x_value));
      createDeployRestScript oc xs model _input_var
;;

let rec createMethodsScript oc _path_list (operations : operation list) =
  match _path_list with 
    [] -> ()
    | x :: xs -> let local_operation = List.hd @@ List.filter (fun y -> String.equal x y.operationlabel) operations in
      if not @@ Int.equal 1 (List.length xs) then
        if Int.equal 1 (List.length xs) then 
          Printf.fprintf oc "  submit alice do\n"
        else 
          Printf.fprintf oc "  local <- submit alice do\n";
        Printf.fprintf oc "    exerciseCmd local %s\n" local_operation.operationlabel; createMethodsScript oc xs operations
;;*)
(*
let solve_path (path : string) templateLabel (alphabet : string list) result initS : unit =
  let cleaned_path = Str.(global_replace (regexp "ε") "" path) in 
  let _path_list = path_to_list cleaned_path alphabet alphabet in
  Printf.printf "Current Path:\n";
  List.iter (Printf.printf "%s ") _path_list;
  let ctx = mk_context [] in
  let _input_var = createConst ctx result.contract_input in 
  
  let exprs = addExpressionsOfEachMethod ctx _path_list result in 
  let g = (mk_goal ctx true false false) in
  (Goal.add g exprs);
  (
    let solver = (mk_solver ctx None) in
    (List.iter (fun a -> (Solver.add solver [ a ])) (get_formulas g)) ;
    if (check solver []) != SATISFIABLE then
      Printf.printf "TestFailedException\n"
    else
      Printf.printf "Assertions are satisfiable.\n";
      
      let model = get_model solver in
      match model with
        None -> Printf.printf "No Model Solution\n";
        | Some m -> 
      
      let fileName = "Main" ^ (string_of_int !counter) in
      let oc = open_out (fileName ^ ".daml") in
      counter := !counter + 1;
      Printf.fprintf oc ("module %s where\n") fileName;
      Printf.fprintf oc "import Daml.Script\nimport Hello\n";
      Printf.fprintf oc "setup = script do \n";
      Printf.fprintf oc "  alice <- allocateParty\"Alice\"\n";


      Printf.fprintf oc "  local <- submit alice do \n";
      Printf.fprintf oc "    createCmd %s  with\n" templateLabel;
      createDeployPartyScript oc result.contract_input;
      createDeployStateScript oc result.contract_input initS;
      createDeployRestScript oc result.contract_input m _input_var;

      createMethodsScript oc _path_list result.operations ;
      close_out oc;
  );
;;

List.iter (Printf.printf "%s\n") result.possible_positive_cases;
*)

let _globalToAuto (global : Automata.Types_j.global) =
  let alphabet = List.filter (fun a -> Bool.not (String.equal a "starts")) (List.map (fun t -> t.action) global.transitions) in
  let transitions = ( List.map (fun t -> t.fromS, t.action, t.toS) (List.filter (fun t -> Bool.not (String.equal t.action "starts")) global.transitions)) in
  { alphabet = alphabet; allStates = global.states; initialState = global.initialS;
    transitions = transitions; acceptStates = global.endS }
;;

let getController transition =
  match List.length transition.new_p with
    0 -> List.nth transition.exi_p.parts 0
    | _ -> (List.nth (List.nth transition.new_p 0).parts 0) 
;;

let createMethodsScript oc name (transition : transition_global) =
  Printf.fprintf oc ("choice %s : %sId\n") transition.action name;
  let deployer = getController transition in
  Printf.fprintf oc ("controller %s \n") deployer;
  Printf.fprintf oc ("do\n");
  Printf.fprintf oc ("assertMsg \"Invalid State\" (this.state == %s)\n") transition.fromS;
  Printf.fprintf oc ("create this with\n");
  Printf.fprintf oc ("state = %s\n\n") transition.toS;
;;

let printResults reg (auto : automaton) =
  Printf.printf "\nRegular expression\n";
  Printf.printf "%s\n" reg;
  
  Printf.printf "\nTransitions\n";
  List.iter (fun (a,b,c) -> Printf.printf "method %s, %s -> %s\n" b a c) auto.transitions;
  
  Printf.printf "\nPossible sequences\n";
  List.iter (Printf.printf "%s\n") (gen_re @@ _regex auto)
;;

let autoToDaml name (global : Automata.Types_j.global) =
  let oc = open_out (name ^ ".daml") in
  Printf.fprintf oc ("module %s where\n") name;
  Printf.fprintf oc ("type %sId = ContractId %s\n") name name;

  Printf.fprintf oc ("data %sStateType\n") name;
  List.iter (fun x ->  Printf.fprintf oc "|%s\n" x) global.states;
  Printf.fprintf oc ("deriving (Eq, Show)\n");

  
  Printf.fprintf oc ("template %s\n") name;
  Printf.fprintf oc ("state : %sStateType\n") name;
  Printf.fprintf oc ("state : %sStateType\n") name;
  List.iter (fun (x : association) -> List.iter (fun y -> 
    Printf.fprintf oc ("%s : Party\n") y) x.parts) global.role_part;
  Printf.fprintf oc ("where %s\n") name;
  let filterTransition = (List.nth (List.nth (List.filter (fun (x : transition_global) -> String.equal "_" x.fromS) global.transitions) 0).new_p 0).parts in
  let deployer = List.nth filterTransition 0 in 
  Printf.fprintf oc ("signatory %s\n") deployer;
  Printf.fprintf oc ("observer %s\n") deployer;
  let (filteredTransitions :transition_global list) = List.filter (fun x -> Bool.not (String.equal "_" x.fromS)) global.transitions in
  List.iter (createMethodsScript oc name) filteredTransitions;
  close_out oc;
;;  



let setup =
  let _global = Atdgen_runtime.Util.Json.from_file read_global "/home/camel/Desktop/git/generate_sc_behaviour/auto.json" in
  let _autoTool = _globalToAuto _global in
  let _regTool = _regex _autoTool in

  printResults _regTool _autoTool;
  autoToDaml "Auction" _global;

  let lines = read_file "/home/camel/Desktop/git/generate_sc_behaviour/Hello.daml" in
  let _states = treatStates lines in
  let deploy = treatDeploy lines in
  let transitions = extractMethods lines false { operationlabel = ""; resultState = ""; requiredState = ""; parameters = []; preconditions = []; postconditions = []} deploy in
  let converted_methods = List.map (fun t -> (t.requiredState, t.operationlabel, t.resultState)) transitions in
  let alphabet = List.map (fun t -> t.operationlabel) transitions in

  let _autoDaml = {alphabet = alphabet; allStates = _states; initialState = "S0"; transitions = converted_methods; acceptStates = ["S2"]} in
  let _regDaml = _regex _autoDaml in

  let pSequenceTool = (gen_re @@ _regex _autoTool) in 
  let pSequenceDaml = (gen_re @@ _regex _autoDaml) in

  let subSet = List.for_all (fun x -> List.mem x pSequenceDaml) pSequenceTool in
  match subSet with 
    false -> Printf.printf "\nThere are sequences that are not covered in the contract.\n";
    | true -> Printf.printf "\nEvery possible sequence in our representation is covered in the contract.\n";
;;

setup;;

Printf.printf "\n";; 