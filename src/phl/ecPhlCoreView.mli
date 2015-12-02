(* --------------------------------------------------------------------
 * Copyright (c) - 2012--2015 - IMDEA Software Institute
 * Copyright (c) - 2012--2015 - Inria
 * 
 * Distributed under the terms of the CeCILL-C-V1 license
 * -------------------------------------------------------------------- *)

(* --------------------------------------------------------------------- *)
open EcCoreGoal.FApi

(* -------------------------------------------------------------------- *)
val t_hoare_of_bdhoareS : backward
val t_hoare_of_bdhoareF : backward
val t_bdhoare_of_hoareS : backward
val t_bdhoare_of_hoareF : backward
val t_hoare_of_muhoareS : backward
val t_hoare_of_muhoareF : backward

(* -------------------------------------------------------------------- *)
val destr_square : EcEnv.env -> EcFol.form ->  EcTypes.memtype * EcFol.form
