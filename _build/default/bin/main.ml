open Lib_generate.Model.FiniteAutomaton
open Lib_generate.Model.Contract
open Lib_generate.Parsing
open Lib_generate.ExtractSC
open Lib_generate
open Z3
open Z3.Expr
open Z3.Arithmetic
open Z3.Arithmetic.Real
open Z3.Goal
open Z3.Solver
open Automata.Types_j

let counter = ref 0;;

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
  let result = Regen._print_allv2 sigma regex (Some 3) None in 
  let (pos, _) = result in 
  Iter.to_list pos
;;

let rec createConst ctx (params : parameter list) =
  match params with 
     [] -> []
    | p :: xs -> [p.labelOfParam, mk_const_s ctx p.labelOfParam] @ createConst ctx xs

let path_analise_word path w =
  if (Str.string_partial_match (Str.regexp path) w 0) 
    then (w, (Str.replace_first (Str.regexp w) "" path))
    else ("","")

(* replace_first *)
let rec path_to_list path alpha alpha_values =
  match alpha with
    [] -> []
    | x :: xs -> 
      if (String.length path) <> 0 
      then
        let result_l = path_analise_word path x in 
        match result_l with 
          (x, y) when x <> "" -> [x] @ path_to_list y alpha_values alpha_values
          | (_, _) -> path_to_list path xs alpha_values 
      else
        []

let is_string_regex regex substring =
  Str.string_match (Str.regexp regex) substring 0 

let rec remove_first_three_elements l count =
  match count, l with
     _, [] -> []
    | 2, _ :: xs -> xs
    | _, _ :: xs -> remove_first_three_elements xs (count + 1)
      
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

(*
*)
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
;;

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



let setup =
  let _global_t = Atdgen_runtime.Util.Json.from_file read_global "/home/camel/Desktop/generate_sc_behaviour/auto.json" in
  
  let lines = read_file "/home/camel/Desktop/generate_sc_behaviour/Hello.daml" in
  let _states = treatStates lines in
  let deploy = treatDeploy lines in
  let transitions = extractMethods lines false { operationlabel = ""; resultState = ""; requiredState = ""; parameters = []; preconditions = []; postconditions = []} deploy in
  let converted_methods = List.map (fun t -> (t.requiredState, t.operationlabel, t.resultState)) transitions in
  let alphabet = List.map (fun t -> t.operationlabel) transitions in

  let _automaton = {alphabet = alphabet; allStates = _states; initialState = "S0"; transitions = converted_methods; acceptStates = ["S1"]} in
  let regular_expression = _regex _automaton in
  Printf.printf "Regular Expression\n %s\n" regular_expression;
  let result = { regex = regular_expression; possible_positive_cases = gen_re @@ _regex _automaton; contract_input = deploy.parametersInput; operations = transitions} in  
 
  List.iter (fun x -> solve_path x deploy.templateLabel alphabet result "S0") result.possible_positive_cases;


;;

setup;;

Printf.printf "File Test executed.\n";;