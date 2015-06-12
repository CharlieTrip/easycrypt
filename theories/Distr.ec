(* --------------------------------------------------------------------
 * Copyright (c) - 2012-2015 - IMDEA Software Institute and INRIA
 * Distributed under the terms of the CeCILL-C license
 * -------------------------------------------------------------------- *)

require import Logic.
require export Pred.
require import Int.
require import Real.
require import Fun.

op charfun (p:'a -> bool) x: real = if p x then 1%r else 0%r.

op mu_x (d:'a distr) x: real = mu d ((=) x).

op weight (d:'a distr): real = mu d True.

op in_supp x (d:'a distr) : bool = 0%r < mu_x d x.

op support (d:'a distr) x = in_supp x d.

pred isuniform (d:'a distr) = forall (x y:'a),
  in_supp x d =>
  in_supp y d =>
  mu_x d x = mu_x d y.

(** Point-wise equality *)
pred (==)(d d':'a distr) =
  (forall x, mu_x d x = mu_x d' x).

(** Event-wise equality *)
pred (===)(d d':'a distr) =
  forall p, mu d p = mu d' p.

(** Axioms *)
axiom mu_bounded (d:'a distr) (p:'a -> bool):
  0%r <= mu d p <= 1%r.

axiom mu_false (d:'a distr): mu d False = 0%r.

axiom mu_sub (d:'a distr) (p q:('a -> bool)):
  p <= q => mu d p <= mu d q.

axiom mu_supp_in (d:'a distr) p:
  mu d p = mu d True <=>
  support d <= p.

axiom mu_or (d:'a distr) (p q:('a -> bool)):
  mu d (p \/ q) = mu d p + mu d q - mu d (p /\ q).

axiom pw_eq (d d':'a distr):
  d == d' <=> d = d'.

axiom uniform_unique (d d':'a distr):
  mu d True = mu d' True =>
  support d = support d' =>
  isuniform d  =>
  isuniform d' =>
  d = d'.

(** Lemmas *)
lemma witness_nzero P (d:'a distr):
  0%r < mu d P => (exists x, P x ).
proof.
  by cut: P <> False => (exists x, P x); smt.
qed.

lemma ew_eq (d d':'a distr):
  d === d' => d = d'.
proof strict.
intros=> ew_eq; rewrite -pw_eq=> x.
by rewrite /mu_x ew_eq.
qed.

lemma nosmt mu_or_le (d:'a distr) (p q:'a -> bool) r1 r2:
  mu d p <= r1 => mu d q <= r2 =>
  mu d (p \/ q) <= r1 + r2 by [].

lemma nosmt mu_and  (d:'a distr) (p q:'a -> bool):
  mu d (p /\ q) = mu d p + mu d q - mu d (p \/ q)
by [].

lemma nosmt mu_and_le_l (d:'a distr) (p q:'a -> bool) r:
  mu d p <= r =>
  mu d (p /\ q) <= r.
proof strict.
apply (Real.Trans _ (mu d p)).
by apply mu_sub; rewrite /Pred.(/\)=> x.
qed.

lemma nosmt mu_and_le_r (d:'a distr) (p q:'a -> bool) r :
  mu d q <= r => 
  mu d (p /\ q) <= r.
proof strict.
apply (Real.Trans _ (mu d q)).
by apply mu_sub; rewrite /Pred.(/\)=> x.
qed.

lemma mu_supp (d:'a distr):
  mu d (support d) = mu d True.
proof strict.
by rewrite mu_supp_in.
qed.

lemma mu_eq (d:'a distr) (p q:'a -> bool):
  p == q => mu d p = mu d q.
proof strict.
by intros=> ext_p_q; congr=> //; apply fun_ext.
qed.

lemma mu_disjoint (d:'a distr) (p q:('a -> bool)):
  (p /\ q) <= False =>
  mu d (p \/ q) = mu d p + mu d q.
proof strict.
intros=> and_p_q_false; rewrite mu_or.
cut ->: (p /\ q) = False by apply leq_asym.
by rewrite mu_false.
qed.

lemma mu_not (d:'a distr) (p:('a -> bool)):
  mu d (!p) = mu d True - mu d p.
proof strict.
cut ->: forall (x y z:real), x = y - z <=> x + z = y by smt.
rewrite -mu_disjoint 2:Excluded_Middle //.
by apply leq_refl; apply Sound.
qed.

lemma mu_split (d:'a distr) (p q:('a -> bool)):
  mu d p = mu d (p /\ q) + mu d (p /\ !q).
proof strict.
rewrite -mu_disjoint; first smt.
by apply mu_eq; smt.
qed.

lemma mu_support (p:('a -> bool)) (d:'a distr):
  mu d p = mu d (p /\ (support d)).
proof strict.
apply Antisymm; last by apply mu_sub; apply And_leq_l.
cut ->: forall (p q:'a -> bool), (p /\ q) = !((!p) \/ (!q))
  by (intros=> p' q'; apply fun_ext; smt).
by rewrite mu_not mu_or !mu_not mu_supp; smt.
qed.

lemma witness_support P (d:'a distr):
  0%r < mu d P <=> (exists x, P x /\ in_supp x d).
proof.
split.
  rewrite mu_support=> nzero.
  apply witness_nzero in nzero; case nzero=> x.
  rewrite /Pred.(/\) /support //= => p_supp.
  by exists x.
  move=> [] x [x_in_P x_in_d].
  cut: mu d ((=) x) <= mu d P /\ 0%r < mu d ((=) x); last smt.
  split; last by rewrite x_in_d.
  by rewrite mu_sub // /Pred.(<=)=> x0 <<-.
qed.

lemma mu_sub_support (d:'a distr) (p q:('a -> bool)):
  (p /\ (support d)) <= (q /\ (support d)) =>
  mu d p <= mu d q.
proof strict.
by intros=> ple_p_q; rewrite (mu_support p) (mu_support q);
   apply mu_sub.
qed.

lemma mu_eq_support (d:'a distr) (p q:('a -> bool)):
  (p /\ (support d)) = (q /\ (support d)) =>
  mu d p = mu d q.
proof strict.
by intros=> eq_supp;
   rewrite (mu_support p) (mu_support q);
   apply mu_eq; rewrite eq_supp.
qed.

lemma weight_0_mu (d:'a distr):
  weight d = 0%r => forall p, mu d p = 0%r
by [].

lemma mu_one (P:'a -> bool) (d:'a distr):
  P == True => 
  weight d = 1%r =>
  mu d P = 1%r.
proof strict.
intros=> heq <-.
rewrite /weight.
congr=> //.
by apply fun_ext.
qed.  

(*** Some useful distributions *)
(** Empty distribution *)
theory Dempty.
  op dempty : 'a distr.

  axiom mu_def (p:'a -> bool): mu dempty p = 0%r.

  lemma unique (d:'a distr):
    weight d = 0%r <=> d = dempty.
  proof strict.
  split; last smt.
  by intros weight_0; rewrite -(pw_eq<:'a> d dempty); smt.
  qed.

  lemma demptyU: isuniform dempty<:'a>. admit. qed.

end Dempty.

(** Point distribution *)
theory Dunit.
  op dunit: 'a -> 'a distr.

  axiom mu_def x (p:'a -> bool):
    mu (dunit x) p = charfun p x.

  lemma nosmt mu_def_in x (p:'a -> bool):
    p x => mu (dunit x) p = 1%r
  by [].

  lemma nosmt mu_def_notin x (p:('a -> bool)):
    !p x => mu (dunit x) p = 0%r
  by [].

  lemma nosmt mu_x_def (x y:'a):
    mu_x (dunit y) x = if x = y then 1%r else 0%r
  by rewrite /mu_x mu_def /charfun.

  lemma nosmt mu_x_def_eq (x:'a):
    mu_x (dunit x) x = 1%r
  by rewrite mu_x_def.

  lemma nosmt mu_x_def_neq (x y:'a):
    x <> y => mu_x (dunit x) y = 0%r
  by (rewrite mu_x_def; smt).

  lemma supp_def (x y:'a):
    in_supp x (dunit y) <=> x = y
  by (rewrite /in_supp mu_x_def; case (x = y)).

  lemma lossless (x:'a):
    weight (dunit x) = 1%r
  by [].

  lemma dunitU (x:'a):
    isuniform (dunit x)
  by [].
end Dunit.

(** Uniform distribution on (closed) integer intervals *)
(* A concrete realization of this distribution using uniform
   distributions on finite sets of integers is available as
   FSet.Dinter_uni.dinter, so these axioms are untrusted. *)
theory Dinter.
  op dinter: int -> int -> int distr.

  axiom supp_def (i j x:int):
    in_supp x (dinter i j) <=> i <= x <= j.

  axiom weight_def (i j:int):
    weight (dinter i j) = if i <= j then 1%r else 0%r.

  axiom mu_x_def (i j x:int):
    mu_x (dinter i j) x =
      if in_supp x (dinter i j)
      then 1%r / (j - i + 1)%r
      else 0%r.

  lemma nosmt mu_x_def_in (i j x:int):
    in_supp x (dinter i j) =>
    mu_x (dinter i j) x = 1%r / (j - i + 1)%r
  by rewrite mu_x_def=> ->.

  lemma nosmt mu_x_def_notin (i j x:int):
    !in_supp x (dinter i j) =>
    mu_x (dinter i j) x = 0%r
  by rewrite mu_x_def -neqF=> ->.

  lemma mu_in_supp (i j : int):
    i <= j => 
    mu (dinter i j) (fun x, i <= x <= j) = 1%r.
  proof strict.
    move=> h; rewrite -(mu_eq_support (dinter i j) True).
      by apply/fun_ext=> x /=; smt.
      by smt.
  qed.

  lemma dinterU (i j:int):
    isuniform (dinter i j)
  by [].
end Dinter.

(** Normalization of a sub-distribution *)
theory Dscale.
  op dscale: 'a distr -> 'a distr.

  axiom supp_def (x:'a) (d:'a distr):
    in_supp x (dscale d) <=> in_supp x d.

  axiom mu_def_0 (d:'a distr):
    weight d = 0%r =>
    forall (p:'a -> bool), mu (dscale d) p = 0%r.

  axiom mu_def_pos (d:'a distr):
    0%r < weight d =>
    forall (p:'a -> bool), mu (dscale d) p = mu d p / weight d.  

  lemma weight_0 (d:'a distr):
    weight d = 0%r => weight (dscale d) = 0%r
  by [].

  lemma weight_pos (d:'a distr):
    0%r < weight d => weight (dscale d) = 1%r.
  proof strict.
  by intros=> H; rewrite /weight mu_def_pos /weight=> //; smt.
  qed.  

  lemma dscaleU (d:'a distr):
    isuniform d => isuniform (dscale d)
  by [].
end Dscale.

(** Distribution resulting from applying a function to a distribution *)
theory Dapply.
  op dapply: ('a -> 'b) -> 'a distr -> 'b distr.

  axiom mu_def (d:'a distr) (f:'a -> 'b) P:
    mu (dapply f d) P = mu d (fun x, P (f x)).

  lemma mu_x_def (d:'a distr) (f:'a -> 'b) x:
    mu_x (dapply f d) x = mu d (fun y, x = f y).
  proof strict.
  by rewrite /mu_x mu_def.
  qed.

  lemma supp_def (d:'a distr) (f:'a -> 'b) y:
    in_supp y (dapply f d) <=> exists x, y = f x /\ in_supp x d.
  proof strict.
  rewrite /in_supp /mu_x mu_def; split.
    rewrite mu_support /Pred.(/\) /= => in_sup. smt.
    intros=> [x]; rewrite /in_supp /mu_x=> [y_def nempty].
    cut : (=) x <= (fun x, y = f x) by (by intros=> w).
    smt.
  qed.

  lemma lossless (d : 'a distr) (f : 'a -> 'b):
    weight (dapply f d) = weight d.
  proof strict.
  by rewrite /weight mu_def /True.
  qed.

  lemma dapply_preim (d:'a distr) (f:'a -> 'b) P:
    mu (dapply f d) P = mu d (preim f P)
  by rewrite mu_def.

  lemma mux_dapply_bij (d:'a distr) (f:'a -> 'b) g x:
    cancel g f => cancel f g =>
    mu (dapply f d) (fun y, y = x) = mu d (fun y, y = g x).
  proof. move=> fK gK; rewrite mu_def; apply mu_eq; smt. qed.

  lemma mux_dapply_pbij (d:'a distr) (f:'a -> 'b) g x P:
    (forall x, P x => g (f x) = x) =>
    (forall y, f (g y) = y) =>
    support d <= P =>
    mu (dapply f d) ((=) x) = mu d ((=) (g x)).
  proof.
    move=> fK gK leq_supp_P.
    rewrite mu_def /= (mu_support (fun y, x = f y)) (mu_support ((=) (g x))); apply mu_eq=> x0.
    rewrite /Pred.(/\) eq_iff /=; split.
      by case => f_x0 sup_x0; split=> //; rewrite -fK 1:leq_supp_P // -f_x0.
      by case => x0_g supp_x0; split=> //; rewrite -(gK x) x0_g.
  qed.
end Dapply.

(** Laplacian *) (* TODO: This is drafty! *)
theory Dlap.
  op dlap : int -> real -> int distr.

  axiom in_supp mean scale x:
    0%r <= scale => in_supp x (dlap mean scale).

(*
  axiom mu_x_def : forall (mean:int, scale:real, x:int),
    0%r <= scale => 
    mu_x (dlap mean scale) x = 
      (1%r / (2%r*scale))
    * real.exp( - (| x%r - mean%r|)) / scale. 
*)

  axiom lossless mean scale:
    0%r <= scale => weight (dlap mean scale) = 1%r.
(* x = $dlap(x1,s)   ~ x = $dlap(0,s) + x1 : ={x1,s} ==> ={x}. *)
end Dlap.

(* ----------------------------------------------------------------- *)

pred positive (f:'a -> real) = forall x, 0%r <= f x.

lemma add_positive (f1 f2:'a -> real) :
   positive f1 => positive f2 => positive (fun x => f1 x + f2 x)
by [].

lemma mul_positive (f1 f2:'a -> real) :
   positive f1 => positive f2 => positive (fun x => f1 x * f2 x)
by [].

(* ---------------------------------------------------------------------- *)
(* Injection of bool into real *) 
op b2r (b:bool) = if b then 1%r else 0%r.

lemma b2r_true : b2r true = 1%r
by [].

lemma b2r_1 (b:bool): b2r b = 1%r <=> b
by [].

lemma b2r_false : b2r false = 0%r
by [].

lemma b2r_0 (b:bool): b2r b = 0%r <=> !b 
by [].

lemma b2r_positive : positive b2r
by [].

lemma b2r_not (b:bool): b2r (!b) = 1%r - b2r b
by [].

lemma b2r_and (b1 b2: bool): b2r(b1 /\ b2) = b2r b1 * b2r b2
by [].

lemma b2r_or (b1 b2:bool): 
    b2r (b1 \/ b2) = b2r b1 + b2r b2 - b2r b1 * b2r b2
by [].

lemma b2r_if b1 b2 b3 : b2r (if b1 then b2 else b3) = b2r b1 * b2r b2 + b2r (!b1) * b2r b3
by [].

(* intergral of f in a distribution d *)
op muf : ('a -> real) -> 'a distr -> real.

lemma muf_congr (f1 f2: 'a -> real) (d1 d2:'a distr): 
  d1 = d2 =>
  (forall a, f1 a = f2 a) =>
  muf f1 d1 = muf f2 d2.
proof. by move=> -> Hf;congr; rewrite -fun_ext. qed.

axiom nosmt muf_le_compat (f1 f2:'a -> real) (d:'a distr) :
  (forall x, in_supp x d => f1 x <= f2 x) =>
  muf f1 d <= muf f2 d.

(* TODO mu should be defined in term of muf *)
axiom muf_pos_0 (d :'a distr) (f:'a -> real) : 
  positive f => 
  muf f d = 0%r <=> (forall x, in_supp x d => f x = 0%r).

axiom muf_b2r (P: 'a -> bool) (d:'a distr) : 
  mu d P = muf (fun a => b2r (P a)) d.

(* FIXME: need to add restriction on f1 f2 *)
axiom muf_add (f1 f2:'a -> real) (d:'a distr):
  muf (fun x => f1 x + f2 x) d = 
  muf f1 d + muf f2 d.

axiom muf_opp (f : 'a -> real) (d:'a distr):
  muf (fun x => -(f x)) d = - muf f d.

lemma muf_sub (f1 f2:'a -> real) (d:'a distr):
  muf (fun x => f1 x - (f2 x)) d = 
  muf f1 d - muf f2 d.
proof.
  cut -> : muf f1 d - muf f2 d = muf f1 d + -muf f2 d by ringeq.
  rewrite -muf_opp -muf_add;apply muf_congr => //= x;ringeq.
qed.

axiom muf_mulc_l (c:real) (f:'a -> real) (d:'a distr):
  muf (fun x => c * f x) d = c * muf f d.

lemma muf_mulc_r (c:real) (f:'a -> real) (d:'a distr):
  muf (fun x => f x * c) d = muf f d * c.
proof.
  rewrite (Real.Comm.Comm (muf f d)) -muf_mulc_l;apply muf_congr => //= x;ringeq.
qed.

lemma muf_c (c:real) (d:'a distr) : 
   muf (fun x => c) d = c * muf (fun x => 1%r) d.
proof. by rewrite -muf_mulc_l. qed.

lemma muf_0 (d:'a distr) :
  muf (fun x => 0%r) d = 0%r.
proof. by rewrite muf_c. qed.

lemma square (d :'a distr) (p:'a -> bool) : 
  muf (fun x => b2r (p x)) d = 0%r <=> (forall x, in_supp x d => !p x)
by [].

lemma square_and (d :'a distr) (p1 p2:'a -> bool) : 
  (muf (fun x => b2r(!(p1 x))) d = 0%r /\ muf (fun x => b2r(!(p2 x))) d = 0%r) <=>
  (muf (fun x => b2r(!(p1 x /\ p2 x))) d = 0%r)
by []. (* WAOU *) 