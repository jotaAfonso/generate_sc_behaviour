module Contract = struct
  type parameter = {
    labelOfParam   : string;
    typeLabel      : string;
  }
  
  type operation = {
    operationlabel : string;
    requiredState  : string;
    resultState    : string;
    parameters     : parameter list;
    preconditions  : string list;
    postconditions : string list;
  }

  type template = {
    templateLabel  : string;
    parametersInput     : parameter list;
    initialState   : string;
  } 

  type regexwithassertions = {
    regex : string;
    possible_positive_cases : string list;
    contract_input : parameter list;
    operations : operation list; 
  } 
end

module FiniteAutomaton = struct
  type transition = string * string * string
	type transitions = transition list
	type automaton = {
		alphabet : string list;
		allStates : string list;
		initialState : string;
		transitions : transitions;
		acceptStates : string list;
	}

  (*
  let _printhashv2 x = 
    Hashtbl.iter (fun x y -> Printf.printf "%s - %s " x y) x
  
  let _printhashv1 x = 
    Hashtbl.iter (fun x y -> Printf.printf "%s -> " x; _printhashv2 y; Printf.printf "\n") x
  *)

  let start_has_incoming auto =
    List.exists (fun (_, _, z) -> 
       String.equal z auto.initialState) auto.transitions
  
  let end_has_outgoing auto =
    List.exists (fun e -> (List.exists (fun (x, _, _) -> 
      String.equal x e) auto.transitions)) auto.acceptStates

  let handle_start_incoming auto =
    if start_has_incoming auto then (
      let local_transitions = auto.transitions in
      let new_transition = ("Qi", "ε", auto.initialState) in
      { auto with initialState = "Qi"; allStates = auto.allStates @ ["Qi"]; transitions = [new_transition] @ local_transitions; }
    ) else auto  
  
  let rec treat_final_transitions end_states =
    match end_states with 
      [] -> []
      | x :: xs -> [(x,"ε","Qf")] @ treat_final_transitions xs
  
  let handle_final_outgoing auto =
    if end_has_outgoing auto then (
      let local_transitions = auto.transitions in
      let new_transitions = treat_final_transitions auto.acceptStates in
      { auto with allStates = auto.allStates @ ["Qf"]; transitions = new_transitions @ local_transitions; acceptStates = ["Qf"] }
    ) else auto
  
  let get_input_symbol auto =
    let input_symbols = Hashtbl.create @@ List.length auto.allStates  in
    List.iter (fun state -> Hashtbl.add input_symbols state (Hashtbl.create @@ List.length auto.allStates)) auto.allStates;
    List.iter (fun (x, y, z) ->
        let transition = Hashtbl.find input_symbols x in
        match Hashtbl.find_opt transition z with
        | Some existing_transition -> Hashtbl.replace transition z (existing_transition ^ "+" ^ y)
        | None -> Hashtbl.replace transition z y)
      auto.transitions;
    input_symbols
  
  let get_pred_succ (auto : automaton) state input_symbols =
    let predecessors = ref [] in
    let successors = ref [] in
    let curr_dict_for_from : (string, string) Hashtbl.t = Hashtbl.create @@ Hashtbl.length input_symbols in  
    Hashtbl.iter (fun st val' ->
        match Hashtbl.find_opt val' state with
          None -> ()
          | x -> Hashtbl.add curr_dict_for_from st (Option.get x)
    ) input_symbols; 
    
    List.iter (fun predecessor ->
        if predecessor <> state then (
          match Hashtbl.find_opt curr_dict_for_from predecessor with
          | Some pred_state_transition when pred_state_transition <> "" -> predecessors := predecessor :: !predecessors
          | _ -> ()
        ))
        auto.allStates;
    List.iter (fun successor ->
        if successor <> state then (
          match Hashtbl.find_opt (Hashtbl.find input_symbols state) successor with
          | Some succ_state_transition when succ_state_transition <> "" -> successors := successor :: !successors
          | _ -> ()
        ))
      auto.allStates;
    (!predecessors, !successors)
  
  let check_self_loop state input_symbols =
    match Hashtbl.find_opt (Hashtbl.find input_symbols state) state with
    | Some self_loop_transition when self_loop_transition <> "" -> true
    | _ -> false
  
  let dfa_to_regex auto input_symbols state_initial state_final =
    List.iter (fun state ->
      let (predecessors, successors) = get_pred_succ auto state input_symbols in
      if not (state = state_initial || state = state_final) then (
        List.iter (fun predecessor ->
          if Hashtbl.mem input_symbols predecessor then
            List.iter (fun successor ->
              if Hashtbl.mem (Hashtbl.find input_symbols predecessor) successor then
                Printf.printf "";
                let pre_suc_input_exp =
                  match Hashtbl.find_opt (Hashtbl.find input_symbols predecessor) successor with
                    | Some transition when transition <> "" -> "(" ^ transition ^ ")"
                    | _ -> ""
                  in
                let self_loop_input_exp =
                  if check_self_loop state input_symbols then
                    "(" ^ (Hashtbl.find (Hashtbl.find input_symbols state) state) ^ ")" ^ "*"
                  else
                    ""
                in
                let from_pre_input_exp =
                  match Hashtbl.find_opt (Hashtbl.find input_symbols predecessor) state with
                    | Some transition when transition <> "" -> "(" ^ transition ^ ")"
                    | _ -> ""
                  in
                let to_suc_input_exp =
                  match Hashtbl.find_opt (Hashtbl.find input_symbols state) successor with
                    | Some transition when transition <> "" -> "(" ^ transition ^ ")"
                    | _ -> ""
                  in
                let new_pre_suc_input_exp =
                  from_pre_input_exp ^ self_loop_input_exp ^ to_suc_input_exp
                in
                let pre_suc_input_exp =
                  if pre_suc_input_exp <> "" then
                    new_pre_suc_input_exp ^ "+" ^ pre_suc_input_exp
                  else
                    new_pre_suc_input_exp
                in
                Hashtbl.replace (Hashtbl.find input_symbols predecessor) successor pre_suc_input_exp
              ) successors
            )
          ) predecessors;
          if not (state = state_initial || state = state_final) then
            Hashtbl.remove input_symbols state
        )
      auto.allStates;
      Hashtbl.find (Hashtbl.find input_symbols state_initial) state_final
      
  let get_regex (automaton : automaton) =
    let auto_start = handle_start_incoming automaton in
    let auto = handle_final_outgoing auto_start in
    let input_symbol = get_input_symbol auto in 
    dfa_to_regex auto input_symbol auto.initialState (List.hd auto.acceptStates)  

end