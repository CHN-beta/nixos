lib: condition: trueResult: falseResult: let inherit (lib) mkMerge mkIf; in
  mkMerge [ ( mkIf condition trueResult ) ( mkIf (!condition) falseResult ) ]
