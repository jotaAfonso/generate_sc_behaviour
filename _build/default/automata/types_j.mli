(* Auto-generated from "types.atd" *)
[@@@ocaml.warning "-27-32-33-35-39"]

type transition_proj = Types_t.transition_proj = {
  fromS: string;
  toS: string;
  action: string
}

type association = Types_t.association = { role: string; parts: string list }

type transition_global = Types_t.transition_global = {
  fromS: string;
  toS: string;
  action: string;
  new_p: association list;
  exi_p: association;
  input: string;
  preC: string;
  postC: string;
  internal: bool;
  extCall: bool
}

type proj = Types_t.proj = {
  id: string;
  role: string;
  parts: string list;
  initialS: string;
  states: string list;
  endS: string list;
  transitions: transition_proj list
}

type global = Types_t.global = {
  id: string;
  initialS: string;
  states: string list;
  endS: string list;
  transitions: transition_global list;
  roles: string list;
  role_part: association list
}

val write_transition_proj :
  Buffer.t -> transition_proj -> unit
  (** Output a JSON value of type {!type:transition_proj}. *)

val string_of_transition_proj :
  ?len:int -> transition_proj -> string
  (** Serialize a value of type {!type:transition_proj}
      into a JSON string.
      @param len specifies the initial length
                 of the buffer used internally.
                 Default: 1024. *)

val read_transition_proj :
  Yojson.Safe.lexer_state -> Lexing.lexbuf -> transition_proj
  (** Input JSON data of type {!type:transition_proj}. *)

val transition_proj_of_string :
  string -> transition_proj
  (** Deserialize JSON data of type {!type:transition_proj}. *)

val write_association :
  Buffer.t -> association -> unit
  (** Output a JSON value of type {!type:association}. *)

val string_of_association :
  ?len:int -> association -> string
  (** Serialize a value of type {!type:association}
      into a JSON string.
      @param len specifies the initial length
                 of the buffer used internally.
                 Default: 1024. *)

val read_association :
  Yojson.Safe.lexer_state -> Lexing.lexbuf -> association
  (** Input JSON data of type {!type:association}. *)

val association_of_string :
  string -> association
  (** Deserialize JSON data of type {!type:association}. *)

val write_transition_global :
  Buffer.t -> transition_global -> unit
  (** Output a JSON value of type {!type:transition_global}. *)

val string_of_transition_global :
  ?len:int -> transition_global -> string
  (** Serialize a value of type {!type:transition_global}
      into a JSON string.
      @param len specifies the initial length
                 of the buffer used internally.
                 Default: 1024. *)

val read_transition_global :
  Yojson.Safe.lexer_state -> Lexing.lexbuf -> transition_global
  (** Input JSON data of type {!type:transition_global}. *)

val transition_global_of_string :
  string -> transition_global
  (** Deserialize JSON data of type {!type:transition_global}. *)

val write_proj :
  Buffer.t -> proj -> unit
  (** Output a JSON value of type {!type:proj}. *)

val string_of_proj :
  ?len:int -> proj -> string
  (** Serialize a value of type {!type:proj}
      into a JSON string.
      @param len specifies the initial length
                 of the buffer used internally.
                 Default: 1024. *)

val read_proj :
  Yojson.Safe.lexer_state -> Lexing.lexbuf -> proj
  (** Input JSON data of type {!type:proj}. *)

val proj_of_string :
  string -> proj
  (** Deserialize JSON data of type {!type:proj}. *)

val write_global :
  Buffer.t -> global -> unit
  (** Output a JSON value of type {!type:global}. *)

val string_of_global :
  ?len:int -> global -> string
  (** Serialize a value of type {!type:global}
      into a JSON string.
      @param len specifies the initial length
                 of the buffer used internally.
                 Default: 1024. *)

val read_global :
  Yojson.Safe.lexer_state -> Lexing.lexbuf -> global
  (** Input JSON data of type {!type:global}. *)

val global_of_string :
  string -> global
  (** Deserialize JSON data of type {!type:global}. *)

