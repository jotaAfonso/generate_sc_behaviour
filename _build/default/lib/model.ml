module Contract = struct
  type operation = {
    operationlabel : string;
    requiredState  : string;
    resultState    : string;
  }

  type parameter = {
    labelOfParam : string;
    typeLabel      : string;
  }

  type template = {
    templateLabel  : string;
    parameters     : parameter list;
    initialState   : string;
  } 
end

module Dfa = struct
  type automaton = {
    states : string list;
    transitions : Contract.operation list;
  }
end