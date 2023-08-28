val reg_exp : string
val populate_table : (string, string) Hashtbl.t -> string list -> unit
val list_states :
  string list ->
  'a -> string list -> (string * (string, string) Hashtbl.t) list
val get_input_symbol :
  string list ->
  Model.Contract.operation list -> (string * (string, string) Hashtbl.t) list
