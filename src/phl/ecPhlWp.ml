(* --------------------------------------------------------------------
 * Copyright (c) - 2012--2016 - IMDEA Software Institute
 * Copyright (c) - 2012--2016 - Inria
 * 
 * Distributed under the terms of the CeCILL-C-V1 license
 * -------------------------------------------------------------------- *)

(* -------------------------------------------------------------------- *)
open EcUtils
open EcParsetree
open EcModules
open EcFol

open EcCoreGoal
open EcLowPhlGoal

(* -------------------------------------------------------------------- *)
module LowInternal = struct
  exception No_wp

  let wp_asgn_aux m lv e (lets, f) =
    let let1 = lv_subst m lv (form_of_expr (Some m) e) in
      (let1::lets, f)

  let rec wp_stmt onesided env m (stmt: EcModules.instr list) letsf =
    match stmt with
    | [] -> stmt, letsf
    | i :: stmt' ->
        try
          let letsf = wp_instr onesided env m i letsf in
          wp_stmt onesided env m stmt' letsf
        with No_wp -> (stmt, letsf)

  and wp_instr onesided env m i letsf =
    match i.i_node with
    | Sasgn (lv,e) ->
        wp_asgn_aux m lv e letsf

    | Sif (e,s1,s2) ->
        let r1,letsf1 = wp_stmt onesided env m (List.rev s1.s_node) letsf in
        let r2,letsf2 = wp_stmt onesided env m (List.rev s2.s_node) letsf in
        if List.is_empty r1 && List.is_empty r2 then begin
          let post1 = mk_let_of_lv_substs env letsf1 in
          let post2 = mk_let_of_lv_substs env letsf2 in
          let post  = f_if (form_of_expr (Some m) e) post1 post2 in
            ([], post)
        end else raise No_wp

    | Sassert e when onesided ->
        let phi = form_of_expr (Some m) e in
        let lets,f = letsf in
        (lets, EcFol.f_and_simpl phi f)

    | _ -> raise No_wp
end

let wp ?(uselet=true) ?(onesided=false) env m s post =
  let r,letsf =
    LowInternal.wp_stmt onesided env m (List.rev s.s_node) ([],post)
  in
  let pre = mk_let_of_lv_substs ~uselet env letsf in
  (List.rev r, pre)

(* -------------------------------------------------------------------- *)
module TacInternal = struct
  let check_wp_progress tc i s rm =
    match i with
    | None   -> List.length s.s_node - List.length rm
    | Some i ->
        if not (List.is_empty rm) then
          tc_error !!tc "remaining %i instruction(s)" (List.length rm);
        i

  let t_hoare_wp ?(uselet=true) i tc =
    let env = FApi.tc1_env tc in
    let hs = tc1_as_hoareS tc in
    let (s_hd, s_wp) = s_split_o i hs.hs_s in
    let m = hs.hs_m in
    let s_wp = EcModules.stmt s_wp in
    let (s_wp, post) = wp ~uselet ~onesided:true env m s_wp hs.hs_po in
    ignore (check_wp_progress tc i hs.hs_s s_wp : int);
    let s = EcModules.stmt (s_hd @ s_wp) in
    let concl = f_hoareS_r { hs with hs_s = s; hs_po = post} in
    FApi.xmutate1 tc `Wp [concl]

  let t_bdhoare_wp ?(uselet=true) i tc =
    let env = FApi.tc1_env tc in
    let bhs = tc1_as_bdhoareS tc in
    let (s_hd, s_wp) = s_split_o i bhs.bhs_s in
    let s_wp = EcModules.stmt s_wp in
    let m = bhs.bhs_m in
    let s_wp,post = wp ~uselet env m s_wp bhs.bhs_po in
    ignore (check_wp_progress tc i bhs.bhs_s s_wp : int);
    let s = EcModules.stmt (s_hd @ s_wp) in
    let concl = f_bdHoareS_r { bhs with bhs_s = s; bhs_po = post} in
    FApi.xmutate1 tc `Wp [concl]

  let t_equiv_wp ?(uselet=true) ij tc =
    let env = FApi.tc1_env tc in
    let es = tc1_as_equivS tc in
    let i = omap fst ij and j = omap snd ij in
    let s_hdl,s_wpl = s_split_o i es.es_sl in
    let s_hdr,s_wpr = s_split_o j es.es_sr in
    let meml, s_wpl = es.es_ml, EcModules.stmt s_wpl in
    let memr, s_wpr = es.es_mr, EcModules.stmt s_wpr in
    let post = es.es_po in
    let s_wpl, post = wp ~uselet env meml s_wpl post in
    let s_wpr, post = wp ~uselet env memr s_wpr post in
    ignore (check_wp_progress tc i es.es_sl s_wpl : int);
    ignore (check_wp_progress tc j es.es_sr s_wpr : int);
    let sl = EcModules.stmt (s_hdl @ s_wpl) in
    let sr = EcModules.stmt (s_hdr @ s_wpr) in
    let concl = f_equivS_r {es with es_sl = sl; es_sr=sr; es_po = post} in
    FApi.xmutate1 tc `Wp [concl]

  let t_muhoare_wp i tc = 
    let env = FApi.tc1_env tc in
    let muh = tc1_as_muhoareS tc in
    let i = ofdfl (fun () -> EcLowMuHoare.max_wp muh.muh_s) i in
    let s_hd,s_tl = s_split i muh.muh_s in
    let po = 
      try EcLowMuHoare.wp_muhoare env (stmt s_tl) muh.muh_po 
      with EcLowMuHoare. NoWpMuhoare ->
        tc_error !!tc "not able to compute the wp for muhoare"
    in
    let concl = f_muhoareS_r {muh with muh_s = stmt s_hd; muh_po = po }in
    FApi.xmutate1 tc `Wp [concl]
       
end

(* -------------------------------------------------------------------- *)
let t_wp_r ?(uselet=true) k g =
  let module T = TacInternal in

  let (th, tbh, te, tmuh) =
    match k with
    | None -> (Some (T.t_hoare_wp   ~uselet None),
               Some (T.t_bdhoare_wp ~uselet None),
               Some (T.t_equiv_wp   ~uselet None),
               Some (T.t_muhoare_wp None)
    )

    | Some (Single i) -> (Some (T.t_hoare_wp   ~uselet (Some i)),
                          Some (T.t_bdhoare_wp ~uselet (Some i)),
                          None (* ------------------- *),
                          Some (T.t_muhoare_wp (Some i)))

    | Some (Double (i, j)) ->
        (None, None, Some (T.t_equiv_wp ~uselet (Some (i, j))), None)

  in
    t_hS_or_bhS_or_eS ?th ?tbh ?te ?tmuh g

let t_wp ?(uselet=true) = FApi.t_low1 "wp" (t_wp_r ~uselet)
