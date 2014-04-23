(* -------------------------------------------------------------------- *)
require import Distr.
(*---*) import Dinter.
require import Int. 

(* -------------------------------------------------------------------- *)
module G = {
  fun f() : int = {
    var k : int;
    k = $dinter 0 10;
    return k;
  }
}.

(* -------------------------------------------------------------------- *)
equiv test : G.f ~ G.f : true ==> res{1}=res{2}.
proof. fun. rnd. skip. smt. qed.

(* -------------------------------------------------------------------- *)
module G' = {
  fun f() : int = {
    var k : int;
    k = $dinter 0 10;
    return k;
  }
}.

(* -------------------------------------------------------------------- *)
equiv test' : G'.f ~ G'.f : true ==> 0 <= res{1} /\ res{1} <= 10.
proof. fun. rnd. skip. smt. qed.

(* -------------------------------------------------------------------- *)
module G3 = {
  var z : int
  fun f() : int  = {
    z = $dinter 0 1;
    return z;
  } 
}.

(* -------------------------------------------------------------------- *)
module G4 = {
  var z : int
  fun f() : int  = {
    z = $dinter 1 2;
    return z;
  } 
}.

(* -------------------------------------------------------------------- *)
equiv different : G3.f ~ G4.f : true ==> G3.z{1} + 1 = G4.z{2}.
proof.
 fun. rnd (lambda z, z + 1) (lambda z, z - 1).
 skip. progress; smt.
qed.

(* -------------------------------------------------------------------- *)
op a : int.
op b : int.
op c : int.
op d : int.

axiom a_le_b : a <= b.
axiom c_le_d : c <= d.

pred Q: (int * int). 

op f    : int -> int.
op finv : int -> int.

(* -------------------------------------------------------------------- *)
axiom f_finv: 
  forall (x:int), a <= x => x <= b => 
    c <= f(x) && f(x) <= d && finv(f(x)) = x.

axiom finv_f: 
  forall (y:int), c <= y => y <= d => 
     a <= finv(y) && finv(y) <= b && f(finv(y)) = y.

(* -------------------------------------------------------------------- *)
module G5 = {
  var z : int
  fun f() : int  = {
    z = $dinter a b;
    return z;
  } 
}.

module G6 = {
  var z : int
  fun f() : int  = {
    z = $dinter c d;
    return z;
  } 
}.

(* -------------------------------------------------------------------- *)
axiom Q_valid: forall (x:int), a <= x => x <= b => Q(x, f(x)).

axiom aux_test_wp:
  forall x, in_supp x (dinter a b) => 
    mu_x (dinter a b) x = mu_x (dinter c d) (f x).

(* -------------------------------------------------------------------- *)
equiv test_wp : G5.f ~ G6.f : true ==> Q(G5.z{1},G6.z{2}).
proof.
 fun. rnd (lambda x, f x) (lambda x, finv x). skip.
 by simplify; do! split; smt.
qed.

(* -------------------------------------------------------------------- *)
equiv test_sp :
  G5.f ~ G6.f :
       Q(G5.z{1},G6.z{2})
   ==>    G6.z{2}  = f(G5.z{1})
       && a       <= G5.z{1}
       && G5.z{1} <= b
       && c       <= G6.z{2}
       && G6.z{2} <= d
       && exists (u v:int), Q(u, v).
proof.
 fun. rnd (lambda x, f x) (lambda x, finv x). skip.
 by simplify; intros &1 &2 H1; do! split; smt.
qed.

(* -------------------------------------------------------------------- *)
module M = {
  fun f() : int = {
    var k : int;
    k = $dinter 0 10;
    return k;
  }
}.

(* -------------------------------------------------------------------- *)
lemma M_in_range:
  equiv [ M.f ~ M.f : true ==> 0 <= res{1} /\ res{2} <= 10 ].
proof.
  fun. rnd{1}. rnd{2}. skip. smt.
qed.
