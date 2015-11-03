(* --------------------------------------------------------------------
 * Copyright (c) - 2012--2015 - IMDEA Software Institute
 * Copyright (c) - 2012--2015 - Inria
 * 
 * Distributed under the terms of the CeCILL-C-V1 license
 * -------------------------------------------------------------------- *)

(* -------------------------------------------------------------------- *)
open EcParsetree
open EcFol
open EcCoreGoal.FApi

(* -------------------------------------------------------------------- *)
val t_hr_forall_intro : backward
val t_hr_exists_elim  : backward
val t_hr_exists_intro : form list -> backward

(* -------------------------------------------------------------------- *)
val process_exists_intro : pformula list -> backward
