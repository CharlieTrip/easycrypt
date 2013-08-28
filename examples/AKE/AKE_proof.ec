require import Bool.
require import Int.
require import Map.
require import FSet.
require import List.
require import Fun.
require import Real.
require import Pair.

require import AKE_defs.

(*{ AKE: Initial game and security definition *)

(* The initial module: we keep it simple and inline the
   definitions of h1 and h2. *)
module AKE(FA : Adv) = {
  
  var evs  : Event list               (* events for queries performed by adversary *)
  var test : Sid option               (* session id of test session *)

  var cH1, cH2 : int                  (* counters for queries *)

  var mH1 : ((Sk * Esk), Eexp) map    (* map for h1 *)
  var sH1 : (Sk * Esk) set            (* adversary queries for h1 *)

  var mH2 : (Sstring, Key) map        (* map for h2 *)
  var sH2 : Sstring set               (* adversary queries for h2 *)

  var mSk        : (Agent, Sk) map    (* map for static secret keys *)
  var mStarted   : (Sidx, Sdata) map  (* map of started sessions *)
  var mCompleted : (Sidx, Epk)   map  (* additional data for completed sessions *)
  
  fun init() : unit = {
    evs = [];
    test = None;
    cH1 = 0;
    cH2 = 0;
    mH1 = Map.empty;
    sH1 = FSet.empty;
    mH2 = Map.empty;
    sH2 = FSet.empty;
    mSk = Map.empty;
    mStarted = Map.empty;
    mCompleted = Map.empty;
  }

  module O : AKE_Oracles = {

    fun h1(a : Sk, x : Esk) : Eexp = {
      var e : Eexp;
      e = $sample_Eexp;
      if (!in_dom (a,x) mH1) {
        mH1.[(a,x)] = e;
      } 
      return proj mH1.[(a,x)];
    }

    fun h1_a(a : Sk, x : Esk) : Eexp option = {
      var r : Eexp option = None;
      var xe : Eexp;
      if (cH1 < qH1) {
        cH1 = cH1 + 1;
        sH1 = add (a,x) sH1;
        xe = h1(a,x);
        r = Some(xe);
      }
      return r;
    }

    fun h2(sstring : Sstring) : Key = {
      var ke : Key;
      ke = $sample_Key;
      if (!in_dom sstring mH2) {
        mH2.[sstring] = ke;
      }
      return proj mH2.[sstring];
    }
 
    fun h2_a(sstring : Sstring) : Key option = {
      var r : Key option = None;
      var ks : Key;
      if (cH2 < qH2) {
        cH2 = cH2 + 1;
        sH2 = add sstring sH2;
        ks = h2(sstring);
        r = Some(ks);
      }
      return r;
    }

    fun init1(i : Sidx, A : Agent, B : Agent) : Epk option = {
      var pX : Epk;
      var x : Esk;
      var x' : Eexp;
      var r : Epk option = None; 
      if (in_dom A mSk && in_dom B mSk && !in_dom i mStarted) {
        x  = $sample_Esk;
        x' = h1(proj (mSk.[A]),x);
        pX = gen_epk(x');
        mStarted.[i] = (A,B,x,x',init);
        r = Some(pX);
        evs = Start(psid_of_sdata(proj mStarted.[i]))::evs;
      }
      return r;
    }

    fun resp(i : Sidx, B : Agent, A : Agent, X : Epk) : Epk option = {
      var y : Esk;
      var y' : Eexp;
      var pY : Epk;
      var r : Epk option = None; 
      if (in_dom A mSk && in_dom B mSk && !in_dom i mStarted && !in_dom i mCompleted) {
        y  = $sample_Esk;
        y' = h1(proj (mSk.[B]),y);
        pY = gen_epk(y');
        mStarted.[i] = (B,A,y,y',resp);
        mCompleted.[i] = X;
        r = Some(pY);
        evs = Accept(sid_of_sdata (proj mStarted.[i]) X)::evs;
      }
      return r;
    }

    fun init2(i : Sidx, Y : Epk) : unit = {
      if (!in_dom i mCompleted && in_dom i mStarted) {
        mCompleted.[i] = Y;
        evs = Accept(sid_of_sdata(proj mStarted.[i]) Y)::evs;
      }
    }

    fun staticRev(A : Agent) : Sk option = {
      var r : Sk option = None;
      if (in_dom A mSk) {
        r = mSk.[A];
        evs = StaticRev(A)::evs;
      }
      return r;
    }

    fun ephemeralRev(i : Sidx) : Esk option = {
      var r : Esk option = None;
      if (in_dom i mStarted) {
        r = Some(sd_esk(proj mStarted.[i]));
        evs = EphemeralRev(psid_of_sdata(proj mStarted.[i]))::evs;
      }
      return r;
    }

    fun computeKey(i : Sidx) : Key option = {
      var r : Key option = None;
      var a, b : Agent;
      var ro : Role;
      var x' : Eexp;
      var x : Esk;
      var k : Key;
      if (in_dom i mCompleted && in_dom i mStarted) {
        (a,b,x,x',ro) = proj mStarted.[i];
        k = h2(gen_sstring x' (proj mSk.[a]) b (proj mCompleted.[i]) ro);
        r = Some k;
      }
      return r;
    }

    fun sessionRev(i : Sidx) : Key option = {
      var r : Key option = None;
      if (in_dom i mCompleted && in_dom i mStarted) {
        evs = SessionRev(sid_of_sdata(proj mStarted.[i]) (proj mCompleted.[i]))::evs;
        r = computeKey(i);
      }
      return r;
    }
  }
  
  module A = FA(O)

  fun main() : bool = {
    var b : bool = def;
    var pks : Pk list = [];
    var t_idx : Sidx = def;
    var key : Key = def;
    var keyo : Key option = def;
    var b' : bool = def;
    var i : int = 0;
    var ska : Sk = def;
    var pka : Pk = def;

    init();

    while (i < qAgent) {
      ska = $sample_Sk;
      pka = gen_pk(ska);
      pks = pka :: pks;
      mSk.[pka] = ska;
    } 

    t_idx = A.choose(pks);
    b = ${0,1};
    if (mStarted.[t_idx] <> None && mCompleted.[t_idx] <> None) {
      test = Some (sid_of_sdata (proj mStarted.[t_idx]) (proj mCompleted.[t_idx]));
        (* the if-condition implies "mem (Accept (proj O.test)) O.evs" *)
      if (b) {
        keyo = O.computeKey(t_idx);
      } else {
        key  = $sample_Key;
        keyo = Some key;
      }
      b' = A.guess(keyo);
    }
    return (b = b');
  }
}.

pred test_fresh(t : Sid option, evs : Event list) =
  t <> None /\ fresh (proj t) evs.

(*{ Explain security notion *)
section.
  (* We want to a find (small) bound eps *)
  const eps : real.

  (* such that the advantage of an adversary is upper bounded by eps. *)
  axiom Secure:
    forall (A <: Adv) &m,
      2%r * Pr[   AKE(A).main() @ &m : res /\ test_fresh AKE.test AKE.evs] - 1%r < eps.
end section.
(*} end: Explain security notion *)

(*} end: Initial game and security definition *)

(*{ First reduction: AKE_EexpRev (replace H1_A by EexpRev oracle) *)

module type AKE_Oracles2 = {
  fun eexpRev(i : Sidx, a : Sk) : Eexp option
  fun h2_a(sstring : Sstring) : Key option
  fun init1(i : Sidx, A : Agent, B : Agent) : Epk option
  fun init2(i : Sidx, Y : Epk) : unit
  fun resp(i : Sidx, B : Agent, A : Agent, X : Epk) : Epk option
  fun staticRev(A : Agent) : Sk option
  fun sessionRev(i : Sidx) : Key option
}.

module type Adv2 (O : AKE_Oracles2) = {
  fun choose(s : Pk list) : Sidx {*}
  fun guess(k : Key option) : bool
}.

type Sdata2 = (Agent * Agent * Role).

op sd2_actor(sd : Sdata2) = let (A,B,r) = sd in A.
op sd2_peer(sd : Sdata2)  = let (A,B,r) = sd in B.
op sd2_role(sd : Sdata2)  = let (A,B,r) = sd in r.

op compute_sid(mStarted : (Sidx, Sdata2) map) (mEexp : (Sidx, Eexp) map)
              (mCompleted : (Sidx, Epk) map) (i : Sidx) : Sid =
  let sd = proj mStarted.[i] in
  (sd2_actor sd,sd2_peer sd,gen_epk(proj mEexp.[i]),proj mCompleted.[i],sd2_role sd).

op compute_psid(mStarted : (Sidx, Sdata2) map) (mEexp : (Sidx, Eexp) map)
               (i : Sidx) : Psid =
  let sd = proj mStarted.[i] in
  (sd2_actor sd, sd2_peer sd, gen_epk(proj mEexp.[i]), sd2_role sd).

module AKE_EexpRev(FA : Adv2) = {
  
  var evs  : Event list               (* events for queries performed by adversary *)
  var test : Sid option               (* session id of test session *)

  var cH1, cH2 : int                  (* counters for queries *)

  var mH2 : (Sstring, Key) map        (* map for h2 *)
  var sH2 : Sstring set               (* adversary queries for h2 *)

  var mSk        : (Agent, Sk) map    (* map for static secret keys *)
  var mEexp      : (Sidx, Eexp) map   (* map for ephemeral exponents of sessions *)
  var mStarted   : (Sidx, Sdata2) map (* map of started sessions *)
  var mCompleted : (Sidx, Epk)   map  (* additional data for completed sessions *)
    
  fun init() : unit = {
    evs = [];
    test = None;
    cH1 = 0;
    cH2 = 0;
    mH2 = Map.empty;
    sH2 = FSet.empty;
    mSk = Map.empty;    
    mEexp = Map.empty;
    mStarted = Map.empty;
    mCompleted = Map.empty;
  }

  module O : AKE_Oracles2 = {
    
    fun eexpRev(i : Sidx, a : Sk) : Eexp option = {
      var r : Eexp option = None;
      if (in_dom i mStarted) {
        evs = EphemeralRev(compute_psid mStarted mEexp i)::evs;
        if (sd2_actor(proj mStarted.[i]) = gen_pk(a)) {
          r = mEexp.[i];
        }
      }
      return r;
    }
    
    fun h2(sstring : Sstring) : Key = {
      var ke : Key;
      ke = $sample_Key;
      if (!in_dom sstring mH2) {
        mH2.[sstring] = ke;
      }
      return proj mH2.[sstring];
    }
 
    fun h2_a(sstring : Sstring) : Key option = {
      var r : Key option = None;
      var ks : Key;
      if (cH2 < qH2) {
        cH2 = cH2 + 1;
        sH2 = add sstring sH2;
        ks = h2(sstring);
        r = Some(ks);
      }
      return r;
    }

    fun init1(i : Sidx, A : Agent, B : Agent) : Epk option = {
      var pX : Epk;
      var r : Epk option = None; 
      if (in_dom A mSk && in_dom B mSk && !in_dom i mStarted) {
        pX = gen_epk(proj mEexp.[i]);
        mStarted.[i] = (A,B,init);
        evs = Start((A,B,pX,init))::evs;
        r = Some(pX);
      }
      return r;
    }

    fun resp(i : Sidx, B : Agent, A : Agent, X : Epk) : Epk option = {
      var pY : Epk;
      var r : Epk option = None;
      if (in_dom A mSk && in_dom B mSk && !in_dom i mStarted && !in_dom i mCompleted) {
        pY = gen_epk(proj mEexp.[i]);
        mStarted.[i] = (B,A,resp);
        mCompleted.[i] = X;
        evs = Accept((B,A,pY,X,resp))::evs;
        r = Some(pY);
      }
      return r;
    }

    fun init2(i : Sidx, Y : Epk) : unit = {
      if (!in_dom i mCompleted && in_dom i mStarted) {
        mCompleted.[i] = Y;
        evs = Accept(compute_sid mStarted mEexp mCompleted i)::evs;
      }
    }

    fun staticRev(A : Agent) : Sk option = {
      var r : Sk option = None;
      if (in_dom A mSk) {
        r = mSk.[A];
        evs = StaticRev(A)::evs;
      }
      return r;
    }

    fun computeKey(i : Sidx) : Key option = {
      var r : Key option = None;
      var a : Agent;
      var b : Agent;
      var ro : Role;
      var k : Key;
      if (in_dom i mCompleted && in_dom i mStarted) {
        (a,b,ro) = proj mStarted.[i];
        k = h2(gen_sstring (proj mEexp.[i]) (proj mSk.[a]) b (proj mCompleted.[i]) ro);
        r = Some k;
      }
      return r;
    }

    fun sessionRev(i : Sidx) : Key option = {
      var r : Key option = None;
      if (in_dom i mCompleted && in_dom i mStarted) {
        evs = SessionRev(compute_sid mStarted mEexp mCompleted i)::evs;
        r = computeKey(i);
      }
      return r;
    }
  }
  
  module A = FA(O)

  fun main() : bool = {
    var b : bool = def;
    var pks : Pk list = [];
    var t_idx : Sidx = def;
    var key : Key = def;
    var keyo : Key option = def;
    var b' : bool = def;
    var i : int = 0;
    var ska : Sk = def;
    var pka : Pk = def;
    var sidxs : Sidx set = univ_Sidx;
    var sidx : Sidx;
    var xa' : Eexp = def;
    
    init();
    while (i < qAgent) {
      ska = $sample_Sk;
      pka = gen_pk(ska);
      pks = pka :: pks;
      mSk.[pka] = ska;
    }

    while (sidxs <> FSet.empty) {
      sidx = pick sidxs;
      sidxs = rm sidx sidxs;
      xa' = $sample_Eexp;
      mEexp.[sidx] = xa';
    } 


    t_idx = A.choose(pks);
    b = ${0,1};
    if (mStarted.[t_idx] <> None && mCompleted.[t_idx] <> None) {
      test = Some (compute_sid mStarted mEexp mCompleted t_idx);
        (* the if-condition implies "mem (Accept (proj O.test)) O.evs" *)
      if (b) {
        keyo = O.computeKey(t_idx);
      } else {
        key  = $sample_Key;
        keyo = Some key;
      }
      b' = A.guess(keyo);
    }
    return (b = b');
  }
}.

pred collision_eexp_eexp(m : (Sidx, Eexp) map) =
  exists i j, in_dom i m /\ m.[i] = m.[j] /\ i <> j.

pred collision_eexp_rcvd(evs : Event list) =
  exists (i : int) (j : int) s1 s2 s3,
     i < j /\  nth evs i = Some (Accept s1) /\
     (   (nth evs j  = Some (Start s2)  /\ psid_sent s2 = sid_rcvd s1)
      \/ (nth evs j  = Some (Accept s3) /\ sid_sent s3 = sid_rcvd s1)).

section.
  (* At this point, we still have to show the following: *)
  axiom Remaining_obligation:
    forall (A <: Adv2) &m,
      2%r * Pr[ AKE_EexpRev(A).main() @ &m : res
                    /\ test_fresh AKE_EexpRev.test AKE_EexpRev.evs
                    /\ ! collision_eexp_eexp(AKE_EexpRev.mEexp) 
                    /\ ! collision_eexp_rcvd(AKE_EexpRev.evs) ]
      - 1%r < eps.
end section.

(*} *)

(*{ Proof: Pr[ AKE : win ] <= eps + Pr[ AKE_EexpRev : win ] *)

op esk_of_sidx (mStarted : (Sidx, Sdata) map) (i : Sidx) =
  sd_esk(proj mStarted.[i]).

op esks(mStarted : (Sidx, Sdata) map) : Esk set =
  img sd_esk (frng mStarted).

op queried_esks(mH1 : ((Sk * Esk), Eexp)  map) : Esk set =
  img snd (fdom mH1).

(* Introduce bad flags for collision events and split mStarted.
   Use accessor functions instead of pattern matching in computeKey.
   Strengthen if-condition such that all map lookups are guarded in sessionRev
   and computeKey. *)
module AKE_1(FA : Adv) = {
  
  var evs  : Event list               (* events for queries performed by adversary *)
  var test : Sid option               (* session id of test session *)

  var cH1, cH2 : int                  (* counters for queries *)

  var mH1 : ((Sk * Esk), Eexp) map    (* map for h1 *)
  var sH1 : (Sk * Esk) set            (* adversary queries for h1 *)

  var mH2 : (Sstring, Key) map        (* map for h2 *)
  var sH2 : Sstring set               (* adversary queries for h2 *)

  var mSk        : (Agent, Sk) map    (* map for static secret keys *)
  var mStarted   : (Sidx, Sdata) map  (* map of started sessions *)
  var mCompleted : (Sidx, Epk)   map  (* additional data for completed sessions *)

  var bad_esk_col : bool              (* esk collision with dom(mH1) *)
    (* The esk sampled in init1/resp is already in dom(mH1). Since
       dom(mH1) = sH1 u <earlier esks>, this corresponds to
       esk-earlier-esk collisions and esk-earlier-h1_a collisions *)

  var bad_esk_norev : bool            (* h1_a query without previous reveal *)
  
  fun init() : unit = {
    evs = [];
    test = None;
    cH1 = 0;
    cH2 = 0;
    mH1 = Map.empty;
    sH1 = FSet.empty;
    mH2 = Map.empty;
    sH2 = FSet.empty;
    mSk = Map.empty;
    mStarted = Map.empty;
    mCompleted = Map.empty;
    bad_esk_col = false;
    bad_esk_norev = false;
  }

  module O : AKE_Oracles = {

    fun h1(a : Sk, x : Esk) : Eexp = {
      var e : Eexp;
      e = $sample_Eexp;
      if (!in_dom (a,x) mH1) {
        mH1.[(a,x)] = e;
      } 
      return proj mH1.[(a,x)];
    }

    fun h1_a(a : Sk, x : Esk) : Eexp option = {
      var r : Eexp option = None;
      var xe : Eexp;
      if (cH1 < qH1) {
        cH1 = cH1 + 1;
        if (any (lambda i, let sd = proj mStarted.[i] in
                           sd_esk sd = x /\
                           ! (mem (EphemeralRev (psid_of_sdata sd)) evs))
                (fdom mStarted)) {
          bad_esk_norev = true;
        }
        sH1 = add (a,x) sH1;
        xe = h1(a,x);
        r = Some(xe);
      }
      return r;
    }

    fun h2(sstring : Sstring) : Key = {
      var ke : Key;
      ke = $sample_Key;
      if (!in_dom sstring mH2) {
        mH2.[sstring] = ke;
      }
      return proj mH2.[sstring];
    }
 
    fun h2_a(sstring : Sstring) : Key option = {
      var r : Key option = None;
      var ks : Key;
      if (cH2 < qH2) {
        cH2 = cH2 + 1;
        sH2 = add sstring sH2;
        ks = h2(sstring);
        r = Some(ks);
      }
      return r;
    }

    fun init1(i : Sidx, A : Agent, B : Agent) : Epk option = {
      var pX : Epk;
      var x : Esk;
      var x' : Eexp;
      var r : Epk option = None; 
      if (in_dom A mSk && in_dom B mSk && !in_dom i mStarted) {
        x  = $sample_Esk;
        if (mem x (queried_esks mH1)) bad_esk_col = true;
        x' = h1(proj (mSk.[A]),x);
        pX = gen_epk(x');
        mStarted.[i] = (A,B,x,x',init);
        r = Some(pX);
        evs = Start(psid_of_sdata(proj mStarted.[i]))::evs;
      }
      return r;
    }

    fun resp(i : Sidx, B : Agent, A : Agent, X : Epk) : Epk option = {
      var y : Esk;
      var y' : Eexp;
      var pY : Epk;
      var r : Epk option = None; 
      if (in_dom A mSk && in_dom B mSk && !in_dom i mStarted && !in_dom i mCompleted) {
        y  = $sample_Esk;
        if (mem y (queried_esks mH1)) bad_esk_col = true;
        y' = h1(proj (mSk.[B]),y);
        pY = gen_epk(y');
        mStarted.[i] = (B,A,y,y',resp);
        mCompleted.[i] = X;
        r = Some(pY);
        evs = Accept(sid_of_sdata (proj mStarted.[i]) X)::evs;
      }
      return r;
    }

    fun init2(i : Sidx, Y : Epk) : unit = {
      if (!in_dom i mCompleted && in_dom i mStarted) {
        mCompleted.[i] = Y;
        evs = Accept(sid_of_sdata(proj mStarted.[i]) Y)::evs;
      }
    }

    fun staticRev(A : Agent) : Sk option = {
      var r : Sk option = None;
      if (in_dom A mSk) {
        r = mSk.[A];
        evs = StaticRev(A)::evs;
      }
      return r;
    }

    fun ephemeralRev(i : Sidx) : Esk option = {
      var r : Esk option = None;
      if (in_dom i mStarted) {
        r = Some(sd_esk(proj mStarted.[i]));
        evs = EphemeralRev(psid_of_sdata(proj mStarted.[i]))::evs;
      }
      return r;
    }

    fun computeKey(i : Sidx) : Key option = {
      var r : Key option = None;
      var sd : Sdata;
      var k : Key;
      if (in_dom i mCompleted && in_dom i mStarted) {
        sd = proj mStarted.[i];
        k = h2(gen_sstring (sd_eexp sd) (proj mSk.[sd_actor sd])
                           (sd_peer sd) (proj mCompleted.[i])
                           (sd_role sd));
        r = Some k;
      }
      return r;
    }

    fun sessionRev(i : Sidx) : Key option = {
      var r : Key option = None;
      if (in_dom i mCompleted && in_dom i mStarted) {
        evs = SessionRev(sid_of_sdata(proj mStarted.[i]) (proj mCompleted.[i]))::evs;
        r = computeKey(i);
      }
      return r;
    }
  }
  
  module A = FA(O)

  fun main() : bool = {
    var b : bool = def;
    var pks : Pk list = [];
    var t_idx : Sidx = def;
    var key : Key = def;
    var keyo : Key option = def;
    var b' : bool = def;
    var i : int = 0;
    var ska : Sk = def;
    var pka : Pk = def;

    init();

    while (i < qAgent) {
      ska = $sample_Sk;
      pka = gen_pk(ska);
      pks = pka :: pks;
      mSk.[pka] = ska;
    } 

    t_idx = A.choose(pks);
    b = ${0,1};
    if (mStarted.[t_idx] <> None && mCompleted.[t_idx] <> None) {
      test = Some (sid_of_sdata (proj mStarted.[t_idx]) (proj mCompleted.[t_idx]));
        (* the if-condition implies "mem (Accept (proj O.test)) O.evs" *)
      if (b) {
        keyo = O.computeKey(t_idx);
      } else {
        key  = $sample_Key;
        keyo = Some key;
      }
      b' = A.guess(keyo);
    }
    return (b = b');
  }
}.

lemma Eq_AKE_AKE_1_O_h1(A <: Adv{AKE, AKE_1}):
  equiv[ AKE(A).O.h1 ~ AKE_1(A).O.h1 :
         (AKE.mH1{1} = AKE_1.mH1{2} /\ ={x,a})
         ==> (AKE.mH1{1} = AKE_1.mH1{2} /\ ={res}) ].
proof strict.
  by fun; eqobs_in.
qed.

lemma Eq_AKE_AKE_1_O_h2(A <: Adv{AKE, AKE_1}):
  equiv[ AKE(A).O.h2 ~ AKE_1(A).O.h2 :
         (AKE.mH2{1} = AKE_1.mH2{2} /\ ={sstring})
         ==> (AKE.mH2{1} = AKE_1.mH2{2} /\ ={res}) ].
proof strict.
  by fun; eqobs_in.
qed.
   
lemma Eq_AKE_AKE_1(A <: Adv{AKE, AKE_1}):
  equiv[ AKE(A).main ~ AKE_1(A).main : true ==>
            (res /\ test_fresh AKE.test AKE.evs){1}
         => (res /\ test_fresh AKE_1.test AKE_1.evs){2}].
proof strict.
  fun.
  eqobs_in
    (AKE.mSk{1}        = AKE_1.mSk{2} /\
     AKE.cH1{1}        = AKE_1.cH1{2} /\
     AKE.cH2{1}        = AKE_1.cH2{2} /\
     AKE.mH1{1}        = AKE_1.mH1{2} /\
     AKE.sH1{1}        = AKE_1.sH1{2} /\
     AKE.mH2{1}        = AKE_1.mH2{2} /\
     AKE.sH2{1}        = AKE_1.sH2{2} /\
     AKE.mStarted{1}   = AKE_1.mStarted{2} /\
     AKE.mCompleted{1} = AKE_1.mCompleted{2} /\
     AKE.evs{1}        = AKE_1.evs{2} /\
     AKE.test{1}       = AKE_1.test{2})
    true :
    (={b,pks,t_idx,key,keyo,b',i,ska,pka} /\
     AKE.mSk{1}        = AKE_1.mSk{2} /\
     AKE.cH1{1}        = AKE_1.cH1{2} /\
     AKE.cH2{1}        = AKE_1.cH2{2} /\
     AKE.mH1{1}        = AKE_1.mH1{2} /\
     AKE.sH1{1}        = AKE_1.sH1{2} /\
     AKE.mH2{1}        = AKE_1.mH2{2} /\
     AKE.sH2{1}        = AKE_1.sH2{2} /\
     AKE.mStarted{1}   = AKE_1.mStarted{2} /\
     AKE.mCompleted{1} = AKE_1.mCompleted{2} /\
     AKE.evs{1}        = AKE_1.evs{2} /\
     AKE.test{1}       = AKE_1.test{2}).
    (* computeKey *)
    fun.
    sp.
    if; [ by smt | | skip; by smt].
    wp.
    call (Eq_AKE_AKE_1_O_h2 A).
    by wp; skip; smt.

    (* resp *)
    fun.
    sp.
    if; [ by smt | | skip; by smt].
    wp.
    call (Eq_AKE_AKE_1_O_h1 A).
    by wp; rnd; wp; skip; smt.

    (* init1 *)
    fun.
    sp.
    if; [ by smt | | skip; by smt].
    wp.
    call (Eq_AKE_AKE_1_O_h1 A).
    by wp; rnd; wp; skip; smt.

    (* h1_a *)
    fun.
    sp.
    if; [ smt | | skip; smt].
    wp.
    call (Eq_AKE_AKE_1_O_h1 A).
    by wp; skip; smt.
qed.

(* Split mStarted into three maps. *)
module AKE_2(FA : Adv) = {
  
  var evs  : Event list               (* events for queries performed by adversary *)
  var test : Sid option               (* session id of test session *)

  var cH1, cH2 : int                  (* counters for queries *)

  var mH1 : ((Sk * Esk), Eexp) map    (* map for h1 *)
  var sH1 : (Sk * Esk) set            (* adversary queries for h1 *)

  var mH2 : (Sstring, Key) map        (* map for h2 *)
  var sH2 : Sstring set               (* adversary queries for h2 *)

  var mSk        : (Agent, Sk) map    (* map for static secret keys *)
  var mEsk       : (Sidx, Esk) map    (* map for ephemeral secret keys *)
  var mEexp      : (Sidx, Eexp) map   (* map for ephemeral exponents of sessions *)
  var mStarted   : (Sidx, Sdata2) map (* map of started sessions *)
  var mCompleted : (Sidx, Epk)   map  (* additional data for completed sessions *)

  var bad_esk_col : bool              (* esk collision with dom(mH1) *)
    (* The esk sampled in init1/resp is already in dom(mH1). Since
       dom(mH1) = sH1 u <earlier esks>, this corresponds to
       esk-earlier-esk collisions and esk-earlier-h1_a collisions *)

  var bad_esk_norev : bool            (* h1_a query without previous reveal *)

  fun init() : unit = {
    evs = [];
    test = None;
    cH1 = 0;
    cH2 = 0;
    mH1 = Map.empty;
    sH1 = FSet.empty;
    mH2 = Map.empty;
    sH2 = FSet.empty;
    mSk = Map.empty;
    mEsk = Map.empty;
    mEexp = Map.empty;
    mStarted = Map.empty;
    mCompleted = Map.empty;
    bad_esk_col = false;
    bad_esk_norev = false;
  }

  module O : AKE_Oracles = {

    fun h1(a : Sk, x : Esk) : Eexp = {
      var e : Eexp;
      e = $sample_Eexp;
      if (!in_dom (a,x) mH1) {
        mH1.[(a,x)] = e;
      } 
      return proj mH1.[(a,x)];
    }

    fun h1_a(a : Sk, x : Esk) : Eexp option = {
      var r : Eexp option = None;
      var xe : Eexp;
      if (cH1 < qH1) {
        cH1 = cH1 + 1;
        if (any (lambda i, proj mEsk.[i] = x /\
                           ! (mem (EphemeralRev (compute_psid mStarted mEexp i)) evs))
                (fdom mStarted)) {
          bad_esk_norev = true;
        }
        sH1 = add (a,x) sH1;
        xe = h1(a,x);
        r = Some(xe);
      }
      return r;
    }

    fun h2(sstring : Sstring) : Key = {
      var ke : Key;
      ke = $sample_Key;
      if (!in_dom sstring mH2) {
        mH2.[sstring] = ke;
      }
      return proj mH2.[sstring];
    }
 
    fun h2_a(sstring : Sstring) : Key option = {
      var r : Key option = None;
      var ks : Key;
      if (cH2 < qH2) {
        cH2 = cH2 + 1;
        sH2 = add sstring sH2;
        ks = h2(sstring);
        r = Some(ks);
      }
      return r;
    }

    fun init1(i : Sidx, A : Agent, B : Agent) : Epk option = {
      var pX : Epk;
      var x : Esk;
      var r : Epk option = None;
      if (in_dom A mSk && in_dom B mSk && !in_dom i mStarted) {
        x = $sample_Esk;
        mEsk.[i] = x;
        if (mem x (queried_esks mH1)) bad_esk_col = true;
        mEexp.[i] = h1(proj (mSk.[A]),x);
        pX = gen_epk(proj mEexp.[i]);
        mStarted.[i] = (A,B,init);
        r = Some(pX);
        evs = Start(compute_psid mStarted mEexp i)::evs;
      }
      return r;
    }

    fun resp(i : Sidx, B : Agent, A : Agent, X : Epk) : Epk option = {
      var y : Esk;
      var pY : Epk;
      var r : Epk option = None; 
      if (in_dom A mSk && in_dom B mSk && !in_dom i mStarted && !in_dom i mCompleted) {
        y  = $sample_Esk;
        mEsk.[i] = y;
        if (mem y (queried_esks mH1)) bad_esk_col = true;
        mEexp.[i] = h1(proj (mSk.[B]),y);
        pY = gen_epk(proj mEexp.[i]);
        mStarted.[i] = (B,A,resp);
        mCompleted.[i] = X;
        r = Some(pY);
        evs = Accept(compute_sid mStarted mEexp mCompleted i)::evs;
      }
      return r;
    }

    fun init2(i : Sidx, Y : Epk) : unit = {
      if (!in_dom i mCompleted && in_dom i mStarted && in_dom i mEexp) {
        mCompleted.[i] = Y;
        evs = Accept(compute_sid mStarted mEexp mCompleted i)::evs;
      }
    }

    fun staticRev(A : Agent) : Sk option = {
      var r : Sk option = None;
      if (in_dom A mSk) {
        r = mSk.[A];
        evs = StaticRev(A)::evs;
      }
      return r;
    }

    fun ephemeralRev(i : Sidx) : Esk option = {
      var r : Esk option = None;
      if (in_dom i mStarted && in_dom i mEexp) {
        r = mEsk.[i];
        evs = EphemeralRev(compute_psid mStarted mEexp i)::evs;
      }
      return r;
    }

    fun computeKey(i : Sidx) : Key option = {
      var r : Key option = None;
      var sd : Sdata2;
      var k : Key;
      if (in_dom i mCompleted && in_dom i mStarted && in_dom i mEexp) {
        sd = proj mStarted.[i];
        k = h2(gen_sstring (proj mEexp.[i]) (proj mSk.[sd2_actor sd])
                           (sd2_peer sd) (proj mCompleted.[i])
                           (sd2_role sd));
        r = Some k;
      }
      return r;
    }

    fun sessionRev(i : Sidx) : Key option = {
      var r : Key option = None;
      if (in_dom i mCompleted && in_dom i mStarted && in_dom i mEexp) {
        evs = SessionRev(compute_sid mStarted mEexp mCompleted i)::evs;
        r = computeKey(i);
      }
      return r;
    }
  }
  
  module A = FA(O)

  fun main() : bool = {
    var b : bool = def;
    var pks : Pk list = [];
    var t_idx : Sidx = def;
    var key : Key = def;
    var keyo : Key option = def;
    var b' : bool = def;
    var i : int = 0;
    var ska : Sk = def;
    var pka : Pk = def;

    init();
    while (i < qAgent) {
      ska = $sample_Sk;
      pka = gen_pk(ska);
      pks = pka :: pks;
      mSk.[pka] = ska;
    } 

    t_idx = A.choose(pks);
    b = ${0,1};
    if (in_dom t_idx mStarted && in_dom t_idx mCompleted && in_dom t_idx mEexp) {
      test = Some (compute_sid mStarted mEexp mCompleted t_idx);
        (* the if-condition implies "mem (Accept (proj O.test)) O.evs" *)
      if (b) {
        keyo = O.computeKey(t_idx);
      } else {
        key  = $sample_Key;
        keyo = Some key;
      }
      b' = A.guess(keyo);
    }
    return (b = b');
  }
}.

(*{ Definitions required for relational invariant between AKE_1 and AKE_2 *)

(* we don't use the predicate because we cannot prevent automatic unfolding
pred eq_map_split_pred
                 (mStarted1 : (Sidx, Sdata)  map) 
                 (mStarted2 : (Sidx, Sdata2) map) 
                 (mEsk      : (Sidx, Esk)    map)
                 (mEexp     : (Sidx, Eexp)   map)
   =    dom mStarted1 = dom mStarted2 /\ dom mStarted2 = dom mEsk
     /\ dom mStarted2 = dom mEexp /\
     (forall (i : Sidx) (sd1 : Sdata) (A B : Agent) (r : Role),
        in_dom i mStarted1 =>
        sd_actor (proj mStarted1.[i]) = sd2_actor (proj mStarted2.[i]) /\
        sd_peer  (proj mStarted1.[i]) = sd2_peer  (proj mStarted2.[i]) /\
        sd_role  (proj mStarted1.[i]) = sd2_role  (proj mStarted2.[i]) /\
        sd_esk   (proj mStarted1.[i]) = proj mEsk.[i] /\
        sd_eexp  (proj mStarted1.[i]) = proj mEexp.[i]).
*)

op eq_map_split : (Sidx, Sdata)  map ->
                  (Sidx, Sdata2) map ->
                  (Sidx, Esk)    map ->
                  (Sidx, Eexp)   map ->
                  bool.

axiom nosmt eq_map_split_def
  (mStarted1 : (Sidx, Sdata)  map) 
  (mStarted2 : (Sidx, Sdata2) map) 
  (mEsk      : (Sidx, Esk)    map)
  (mEexp     : (Sidx, Eexp)   map):
        eq_map_split mStarted1 mStarted2 mEsk mEexp
   = (    dom mStarted1 = dom mStarted2 /\ dom mStarted2 = dom mEsk
      /\ dom mStarted2 = dom mEexp /\
      (forall (i : Sidx) (sd1 : Sdata) (A B : Agent) (r : Role),
         in_dom i mStarted1 =>
         sd_actor (proj mStarted1.[i]) = sd2_actor (proj mStarted2.[i]) /\
         sd_peer  (proj mStarted1.[i]) = sd2_peer  (proj mStarted2.[i]) /\
         sd_role  (proj mStarted1.[i]) = sd2_role  (proj mStarted2.[i]) /\
         sd_esk   (proj mStarted1.[i]) = proj mEsk.[i] /\
         sd_eexp  (proj mStarted1.[i]) = proj mEexp.[i])).

lemma eq_map_split_1(mStarted1 : (Sidx, Sdata)  map)
                    (mStarted2 : (Sidx, Sdata2) map)
                    (mEsk      : (Sidx, Esk)    map) 
                    (mEexp     : (Sidx, Eexp)   map)
                    (i : Sidx):
     in_dom i mStarted1
  => eq_map_split mStarted1 mStarted2 mEsk mEexp
  => psid_of_sdata (proj mStarted1.[i]) = compute_psid mStarted2 mEexp i.
proof strict.
  rewrite /psid_of_sdata /compute_psid eq_map_split_def.
  elim /tuple5_ind (proj mStarted1.[i]).
  smt.
qed.

lemma eq_map_split_2(mStarted1  : (Sidx, Sdata)  map)
                    (mStarted2  : (Sidx, Sdata2) map)
                    (mCompleted : (Sidx, Epk)    map)
                    (mEsk       : (Sidx, Esk) map) 
                    (mEexp      : (Sidx, Eexp) map)
                    (i : Sidx):
     in_dom i mStarted1
  => in_dom i mCompleted
  => eq_map_split mStarted1 mStarted2 mEsk mEexp
  =>   sid_of_sdata (proj mStarted1.[i]) (proj mCompleted.[i])
     = compute_sid mStarted2 mEexp mCompleted i.
proof strict.
  rewrite eq_map_split_def /sid_of_sdata /compute_sid.
  elim /tuple5_ind (proj mStarted1.[i]).
  smt.
qed.

lemma eq_map_split_3(mStarted1  : (Sidx, Sdata)  map)
                    (mStarted2  : (Sidx, Sdata2) map)
                    (mCompleted : (Sidx, Epk)    map)
                    (mEsk       : (Sidx, Esk) map) 
                    (mEexp      : (Sidx, Eexp) map)
                    (i : Sidx):
     eq_map_split mStarted1 mStarted2 mEsk mEexp
  => in_dom i mStarted1 = in_dom i mStarted2.
proof strict.
  by rewrite eq_map_split_def; smt.
qed.

lemma eq_map_split_4(mStarted1  : (Sidx, Sdata)  map)
                    (mStarted2  : (Sidx, Sdata2) map)
                    (mCompleted : (Sidx, Epk)    map)
                    (mEsk       : (Sidx, Esk) map) 
                    (mEexp      : (Sidx, Eexp) map)
                    (i : Sidx):
     eq_map_split mStarted1 mStarted2 mEsk mEexp
  => in_dom i mStarted1 = in_dom i mEexp.
proof strict.
  by rewrite eq_map_split_def; smt.
qed.

lemma eq_map_split_5(mStarted1  : (Sidx, Sdata)  map)
                    (mStarted2  : (Sidx, Sdata2) map)
                    (mEsk       : (Sidx, Esk)    map) 
                    (mEexp      : (Sidx, Eexp)   map)
                    (evs : Event list)
                    (x : Esk):
     eq_map_split mStarted1 mStarted2 mEsk mEexp
  =>   any (lambda i, let sd = proj mStarted1.[i] in
                      sd_esk sd = x /\
                      ! (mem (EphemeralRev (psid_of_sdata sd)) evs))
           (fdom mStarted1)
     = any (lambda i, proj mEsk.[i] = x /\
                      ! (mem (EphemeralRev (compute_psid mStarted2 mEexp i)) evs))
            (fdom mStarted2).
proof strict.
  rewrite eq_map_split_def /psid_of_sdata /compute_psid !any_def /fdom /fdom rw_eq_iff.
  cut Fin1: ISet.Finite.finite (dom mStarted1). smt.
    (* FIXME: make Sidx finite type 0 .. qsessions or axiomatize the condition *)
  cut Fin2: ISet.Finite.finite (dom mStarted2). smt.
  progress.
  exists x0.
  cut ->: mem x0 ((ISet.Finite.toFSet (dom mStarted2))) = ISet.mem x0 (dom mStarted2); first smt.
  generalize H3;
    cut ->:   mem x0 ((ISet.Finite.toFSet (dom mStarted1)))
            = ISet.mem x0 (dom mStarted1); first smt;
    intros=> H3.
  smt.
  exists x0.
  cut ->:   mem x0 ((ISet.Finite.toFSet (dom mStarted1)))
          = ISet.mem x0 (dom mStarted1); first smt.
  generalize H3;
    cut ->:   mem x0 ((ISet.Finite.toFSet (dom mStarted2)))
            = ISet.mem x0 (dom mStarted2); first smt;
    intros=> H3.
  smt.
qed.

(*} end: Definitions required for relational invariant between AKE_1 and AKE_2 *)

(*{ First handle oracles that are unaffected by changes *)

lemma Eq_AKE_1_AKE_2_O_h1(A <: Adv{AKE, AKE_1}):
  equiv[ AKE_1(A).O.h1 ~ AKE_2(A).O.h1 :
         (AKE_1.mH1{1} = AKE_2.mH1{2} /\ ={x,a})
         ==> (AKE_1.mH1{1} = AKE_2.mH1{2} /\ ={res}) ].
proof strict.
  by fun; eqobs_in.
qed.

lemma Eq_AKE_1_AKE_2_O_h2(A <: Adv{AKE, AKE_1}):
  equiv[ AKE_1(A).O.h2 ~ AKE_2(A).O.h2 :
         (AKE_1.mH2{1} = AKE_2.mH2{2} /\ ={sstring})
         ==> (AKE_1.mH2{1} = AKE_2.mH2{2} /\ ={res}) ].
proof strict.
  by fun; eqobs_in.
qed.
  
lemma Eq_AKE_1_AKE_2_O_h2_a(A <: Adv{AKE, AKE_1}):
  equiv[ AKE_1(A).O.h2_a ~ AKE_2(A).O.h2_a :
         ( ={sstring} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2})
         ==>
         ( ={res} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2}) ].
proof strict.
  fun.
  sp.
  if; [ by smt | | by skip; smt ].
  wp.
  call (Eq_AKE_1_AKE_2_O_h2 A).
  wp.
  skip; smt.
qed.

lemma Eq_AKE_1_AKE_2_O_staticRev(A <: Adv{AKE, AKE_1}):
  equiv[ AKE_1(A).O.staticRev ~ AKE_2(A).O.staticRev :
         ( ={A} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2})
         ==>
         ( ={res} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2}) ].
proof strict.
  fun; wp; skip; smt.
qed.

(*} end: First handle oracles that are unaffected by changes *)

(*{ Then handle oracles that only read the modified maps. *)

lemma Eq_AKE_1_AKE_2_O_init2(A <: Adv{AKE, AKE_1}):
  equiv[ AKE_1(A).O.init2 ~ AKE_2(A).O.init2 :
          ( ={i,Y} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2})
         ==>
          ( ={res} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2}) ].
proof strict.
  fun.
  if ; [ by smt | | by skip; smt ].
  by wp; skip; smt.
qed.

lemma Eq_AKE_1_AKE_2_O_ephemeralRev(A <: Adv{AKE, AKE_1}):
  equiv[ AKE_1(A).O.ephemeralRev ~ AKE_2(A).O.ephemeralRev :
          ( ={i} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2})
         ==>
          ( ={res} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2}) ].
proof strict.
  fun.
  wp;  skip; intros &1 &2.
  rewrite eq_map_split_def.
  by progress; smt.
qed.

lemma Eq_AKE_1_AKE_2_O_computeKey(A <: Adv{AKE, AKE_1}):
  equiv[ AKE_1(A).O.computeKey ~ AKE_2(A).O.computeKey :
          ( ={i} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2})
         ==>
          ( ={res} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2}) ].
proof strict.
  fun.
  sp.
  if ;[ by smt | | by skip; smt ].
  wp.
  call (Eq_AKE_1_AKE_2_O_h2 A).
  wp; skip. progress.
    by generalize H; rewrite eq_map_split_def; smt.
    by smt.
qed.

lemma Eq_AKE_1_AKE_2_O_sessionRev(A <: Adv{AKE, AKE_1}):
  equiv[ AKE_1(A).O.sessionRev ~ AKE_2(A).O.sessionRev :
          ( ={i} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2})
         ==>
         ( ={res} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2}) ].
proof strict.
  fun.
  sp.
  if; [ by smt | | by skip; smt ]. 
  call (Eq_AKE_1_AKE_2_O_computeKey A).
  wp; skip. smt.
qed.

lemma Eq_AKE_1_AKE_2_O_h1_a(A <: Adv{AKE, AKE_1}):
  equiv[ AKE_1(A).O.h1_a ~ AKE_2(A).O.h1_a :
         ( ={a,x} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2})
         ==>
         ( ={res} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2}) ].
proof strict.
  fun.
  sp.
  if; [ by smt | | by skip; smt ].
  (* we want to use 'if' for the command setting bad *)
  seq 1 1:
     ( ={a,x} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2});
    first by wp; skip; smt.
  seq 2 2:
    ( ={a,x} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2}).
    if.
      simplify.
      intros &1 &2 H.
      cut H1:= eq_map_split_5 AKE_1.mStarted{1} AKE_2.mStarted{2}
                              AKE_2.mEsk{2} AKE_2.mEexp{2} AKE_2.evs{2} x{2} _. smt.
      generalize H.
      progress.
      smt.
      smt.
    wp; skip; smt.
    wp; skip; smt.
  wp.
  call (Eq_AKE_1_AKE_2_O_h1 A).
  skip; smt.
qed.

(*} end: Then handle oracles that only read the modified maps*)

(*{ Lastly handle oracles that write the modified maps. *)

lemma Eq_AKE_1_AKE_2_O_init1(A <: Adv{AKE, AKE_1}):
  equiv[ AKE_1(A).O.init1 ~ AKE_2(A).O.init1 :
         ( ={i,A,B} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2})
         ==>
         ( ={res} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2}) ].
proof strict.
  fun.
  sp.
  if; [ by smt | | skip; by smt ].
  sp.
  swap {2} 2 1.
  wp.
  call (Eq_AKE_1_AKE_2_O_h1 A).
  seq 1 1:
    ( ={i,A,B,r,x} /\
     AKE_1.evs{1}         = AKE_2.evs{2} /\
     AKE_1.test{1}        = AKE_2.test{2} /\
     AKE_1.cH1{1}         = AKE_2.cH1{2} /\
     AKE_1.cH2{1}         = AKE_2.cH2{2} /\
     AKE_1.mH1{1}         = AKE_2.mH1{2} /\
     AKE_1.sH1{1}         = AKE_2.sH1{2} /\
     AKE_1.mH2{1}         = AKE_2.mH2{2} /\
     AKE_1.sH2{1}         = AKE_2.sH2{2} /\
     AKE_1.mSk{1}         = AKE_2.mSk{2} /\
     AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
     AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
     AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
     eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                  AKE_2.mEsk{2} AKE_2.mEexp{2}).
  rnd; skip; smt.
  seq 1 1:
    ( ={i,A,B,r,x} /\
     AKE_1.evs{1}         = AKE_2.evs{2} /\
     AKE_1.test{1}        = AKE_2.test{2} /\
     AKE_1.cH1{1}         = AKE_2.cH1{2} /\
     AKE_1.cH2{1}         = AKE_2.cH2{2} /\
     AKE_1.mH1{1}         = AKE_2.mH1{2} /\
     AKE_1.sH1{1}         = AKE_2.sH1{2} /\
     AKE_1.mH2{1}         = AKE_2.mH2{2} /\
     AKE_1.sH2{1}         = AKE_2.sH2{2} /\
     AKE_1.mSk{1}         = AKE_2.mSk{2} /\
     AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
     AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
     AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
     eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                  AKE_2.mEsk{2} AKE_2.mEexp{2}).
  if; [ by smt | | by skip; smt ].
    by wp; skip; smt.
  wp. skip. progress. smt. smt.
  generalize H.
  rewrite !eq_map_split_def.
  progress. smt. smt. smt. smt. smt. 
  case (i{2} = i0).
    intros eq. rewrite !eq !get_setE; smt.
  intros neq. rewrite !get_setNE. smt. smt.
    generalize H3.
    rewrite (in_dom_setNE i0 AKE_1.mStarted{1}). smt. smt.
  smt.
  smt.
qed.

lemma Eq_AKE_1_AKE_2_O_resp(A <: Adv{AKE, AKE_1}):
  equiv[ AKE_1(A).O.resp ~ AKE_2(A).O.resp :
         ( ={i, B, A, X} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2})
         ==>
         ( ={res} /\
           AKE_1.evs{1}         = AKE_2.evs{2} /\
           AKE_1.test{1}        = AKE_2.test{2} /\
           AKE_1.cH1{1}         = AKE_2.cH1{2} /\
           AKE_1.cH2{1}         = AKE_2.cH2{2} /\
           AKE_1.mH1{1}         = AKE_2.mH1{2} /\
           AKE_1.sH1{1}         = AKE_2.sH1{2} /\
           AKE_1.mH2{1}         = AKE_2.mH2{2} /\
           AKE_1.sH2{1}         = AKE_2.sH2{2} /\
           AKE_1.mSk{1}         = AKE_2.mSk{2} /\
           AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
           AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
           AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
           eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                        AKE_2.mEsk{2} AKE_2.mEexp{2}) ].
proof strict.
  fun.
  sp.
  if; [ by smt | | skip; by smt ].
  wp.
  call (Eq_AKE_1_AKE_2_O_h1 A).
  swap {2} 2 1.
  sp.
  seq 1 1 :
    ( ={i,A,B,r,y,X} /\
     AKE_1.evs{1}         = AKE_2.evs{2} /\
     AKE_1.test{1}        = AKE_2.test{2} /\
     AKE_1.cH1{1}         = AKE_2.cH1{2} /\
     AKE_1.cH2{1}         = AKE_2.cH2{2} /\
     AKE_1.mH1{1}         = AKE_2.mH1{2} /\
     AKE_1.sH1{1}         = AKE_2.sH1{2} /\
     AKE_1.mH2{1}         = AKE_2.mH2{2} /\
     AKE_1.sH2{1}         = AKE_2.sH2{2} /\
     AKE_1.mSk{1}         = AKE_2.mSk{2} /\
     AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
     AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
     AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
     eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                  AKE_2.mEsk{2} AKE_2.mEexp{2}).
  rnd. skip. smt.
  seq 1 1 :
    ( ={i,A,B,r,y,X} /\
     AKE_1.evs{1}         = AKE_2.evs{2} /\
     AKE_1.test{1}        = AKE_2.test{2} /\
     AKE_1.cH1{1}         = AKE_2.cH1{2} /\
     AKE_1.cH2{1}         = AKE_2.cH2{2} /\
     AKE_1.mH1{1}         = AKE_2.mH1{2} /\
     AKE_1.sH1{1}         = AKE_2.sH1{2} /\
     AKE_1.mH2{1}         = AKE_2.mH2{2} /\
     AKE_1.sH2{1}         = AKE_2.sH2{2} /\
     AKE_1.mSk{1}         = AKE_2.mSk{2} /\
     AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
     AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
     AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
     eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                  AKE_2.mEsk{2} AKE_2.mEexp{2}).
  if. smt. wp; skip; smt. skip; smt.
  wp; skip.
  simplify.
  intros &1 &2 H.
  generalize H.
  progress.
    smt.
    smt.
  generalize H. rewrite !eq_map_split_def.
  progress.
    smt. smt. smt. smt. smt.
  case (i{2} = i0).
    intros eq. rewrite !eq !get_setE; smt.
  intros neq. rewrite !get_setNE. smt. smt.
    generalize H3.
    rewrite (in_dom_setNE i0 AKE_1.mStarted{1}). smt. smt.
  smt.
  smt.
qed.

(*} end: Lastly handle oracles that write the modified maps. *)

lemma Eq_AKE_1_AKE_2(A <: Adv{AKE_1, AKE_2}):
  equiv[ AKE_1(A).main ~ AKE_2(A).main : true ==>
            (res /\ test_fresh AKE_1.test AKE_1.evs /\
             !AKE_1.bad_esk_col /\ !AKE_1.bad_esk_norev){1}
         => (res /\ test_fresh AKE_2.test AKE_2.evs /\
             !AKE_2.bad_esk_col /\ !AKE_2.bad_esk_norev){2} ].
proof strict.
  fun.
  inline AKE_1(A).init AKE_2(A).init.
  seq 22 24:
    ( ={b,pks,t_idx,key,keyo,b',i,ska,pka} /\
      AKE_1.evs{1}         = AKE_2.evs{2} /\
      AKE_1.test{1}        = AKE_2.test{2} /\
      AKE_1.cH1{1}         = AKE_2.cH1{2} /\
      AKE_1.cH2{1}         = AKE_2.cH2{2} /\
      AKE_1.mH1{1}         = AKE_2.mH1{2} /\
      AKE_1.sH1{1}         = AKE_2.sH1{2} /\
      AKE_1.mH2{1}         = AKE_2.mH2{2} /\
      AKE_1.sH2{1}         = AKE_2.sH2{2} /\
      AKE_1.mSk{1}         = AKE_2.mSk{2} /\
      AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
      AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
      AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
      eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                   AKE_2.mEsk{2} AKE_2.mEexp{2}).
  by wp; skip; rewrite eq_map_split_def; smt.
  seq 1 1:
    ( ={b,pks,t_idx,key,keyo,b',i,ska,pka} /\
      AKE_1.evs{1}         = AKE_2.evs{2} /\
      AKE_1.test{1}        = AKE_2.test{2} /\
      AKE_1.cH1{1}         = AKE_2.cH1{2} /\
      AKE_1.cH2{1}         = AKE_2.cH2{2} /\
      AKE_1.mH1{1}         = AKE_2.mH1{2} /\
      AKE_1.sH1{1}         = AKE_2.sH1{2} /\
      AKE_1.mH2{1}         = AKE_2.mH2{2} /\
      AKE_1.sH2{1}         = AKE_2.sH2{2} /\
      AKE_1.mSk{1}         = AKE_2.mSk{2} /\
      AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
      AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
      AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
      eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                   AKE_2.mEsk{2} AKE_2.mEexp{2}).
  while 
    ( ={b,pks,t_idx,key,keyo,b',i,ska,pka} /\
      AKE_1.evs{1}         = AKE_2.evs{2} /\
      AKE_1.test{1}        = AKE_2.test{2} /\
      AKE_1.cH1{1}         = AKE_2.cH1{2} /\
      AKE_1.cH2{1}         = AKE_2.cH2{2} /\
      AKE_1.mH1{1}         = AKE_2.mH1{2} /\
      AKE_1.sH1{1}         = AKE_2.sH1{2} /\
      AKE_1.mH2{1}         = AKE_2.mH2{2} /\
      AKE_1.sH2{1}         = AKE_2.sH2{2} /\
      AKE_1.mSk{1}         = AKE_2.mSk{2} /\
      AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
      AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
      AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
      eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                   AKE_2.mEsk{2} AKE_2.mEexp{2}).
  by wp; rnd; skip; smt.
  by skip; smt.
  seq 1 1:
    ( ={b,pks,t_idx,key,keyo,b',i,ska,pka} /\
      AKE_1.evs{1}         = AKE_2.evs{2} /\
      AKE_1.test{1}        = AKE_2.test{2} /\
      AKE_1.cH1{1}         = AKE_2.cH1{2} /\
      AKE_1.cH2{1}         = AKE_2.cH2{2} /\
      AKE_1.mH1{1}         = AKE_2.mH1{2} /\
      AKE_1.sH1{1}         = AKE_2.sH1{2} /\
      AKE_1.mH2{1}         = AKE_2.mH2{2} /\
      AKE_1.sH2{1}         = AKE_2.sH2{2} /\
      AKE_1.mSk{1}         = AKE_2.mSk{2} /\
      AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
      AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
      AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
      eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                   AKE_2.mEsk{2} AKE_2.mEexp{2} /\
      ={glob A}).
  call 
     (_: 
      AKE_1.evs{1}         = AKE_2.evs{2} /\
      AKE_1.test{1}        = AKE_2.test{2} /\
      AKE_1.cH1{1}         = AKE_2.cH1{2} /\
      AKE_1.cH2{1}         = AKE_2.cH2{2} /\
      AKE_1.mH1{1}         = AKE_2.mH1{2} /\
      AKE_1.sH1{1}         = AKE_2.sH1{2} /\
      AKE_1.mH2{1}         = AKE_2.mH2{2} /\
      AKE_1.sH2{1}         = AKE_2.sH2{2} /\
      AKE_1.mSk{1}         = AKE_2.mSk{2} /\
      AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
      AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
      AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
      eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                   AKE_2.mEsk{2} AKE_2.mEexp{2}).
    apply (Eq_AKE_1_AKE_2_O_h1_a A).
    apply (Eq_AKE_1_AKE_2_O_h2_a A).
    apply (Eq_AKE_1_AKE_2_O_init1 A).
    apply (Eq_AKE_1_AKE_2_O_init2 A).
    apply (Eq_AKE_1_AKE_2_O_resp A).
    apply (Eq_AKE_1_AKE_2_O_staticRev A).
    apply (Eq_AKE_1_AKE_2_O_ephemeralRev A).
    apply (Eq_AKE_1_AKE_2_O_sessionRev A).
    by skip; smt.
    seq 1 1:
    ( ={b,pks,t_idx,key,keyo,b',i,ska,pka} /\
      AKE_1.evs{1}         = AKE_2.evs{2} /\
      AKE_1.test{1}        = AKE_2.test{2} /\
      AKE_1.cH1{1}         = AKE_2.cH1{2} /\
      AKE_1.cH2{1}         = AKE_2.cH2{2} /\
      AKE_1.mH1{1}         = AKE_2.mH1{2} /\
      AKE_1.sH1{1}         = AKE_2.sH1{2} /\
      AKE_1.mH2{1}         = AKE_2.mH2{2} /\
      AKE_1.sH2{1}         = AKE_2.sH2{2} /\
      AKE_1.mSk{1}         = AKE_2.mSk{2} /\
      AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
      AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
      AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
      eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                   AKE_2.mEsk{2} AKE_2.mEexp{2} /\
      ={glob A}).
    by rnd; skip; smt.
    if; [ by smt | | by skip; smt ].
    call 
     (_: 
      AKE_1.evs{1}         = AKE_2.evs{2} /\
      AKE_1.test{1}        = AKE_2.test{2} /\
      AKE_1.cH1{1}         = AKE_2.cH1{2} /\
      AKE_1.cH2{1}         = AKE_2.cH2{2} /\
      AKE_1.mH1{1}         = AKE_2.mH1{2} /\
      AKE_1.sH1{1}         = AKE_2.sH1{2} /\
      AKE_1.mH2{1}         = AKE_2.mH2{2} /\
      AKE_1.sH2{1}         = AKE_2.sH2{2} /\
      AKE_1.mSk{1}         = AKE_2.mSk{2} /\
      AKE_1.mCompleted{1}  = AKE_2.mCompleted{2} /\
      AKE_1.bad_esk_col{1} = AKE_2.bad_esk_col{2} /\
      AKE_1.bad_esk_norev{1} = AKE_2.bad_esk_norev{2} /\
      eq_map_split AKE_1.mStarted{1} AKE_2.mStarted{2}
                   AKE_2.mEsk{2} AKE_2.mEexp{2}).
    apply (Eq_AKE_1_AKE_2_O_h1_a A).
    apply (Eq_AKE_1_AKE_2_O_h2_a A).
    apply (Eq_AKE_1_AKE_2_O_init1 A).
    apply (Eq_AKE_1_AKE_2_O_init2 A).
    apply (Eq_AKE_1_AKE_2_O_resp A).
    apply (Eq_AKE_1_AKE_2_O_staticRev A).
    apply (Eq_AKE_1_AKE_2_O_ephemeralRev A).
    apply (Eq_AKE_1_AKE_2_O_sessionRev A).
    sp.
    if; first by smt.
    call (Eq_AKE_1_AKE_2_O_computeKey A).
    by skip; progress; smt.
    by wp; rnd; skip; progress; smt.
qed.

(* Move sampling of ephemeral exponents to loop in main.
   Can be justified by making domain finite (subtype of int)
   and using lazy/eager RO transformation.
*)
module AKE_3(FA : Adv) = {
  
  var evs  : Event list               (* events for queries performed by adversary *)
  var test : Sid option               (* session id of test session *)

  var cH1, cH2 : int                  (* counters for queries *)

  var mH1 : ((Sk * Esk), Eexp) map    (* map for h1 *)
  var sH1 : (Sk * Esk) set            (* adversary queries for h1 *)

  var mH2 : (Sstring, Key) map        (* map for h2 *)
  var sH2 : Sstring set               (* adversary queries for h2 *)

  var mSk        : (Agent, Sk) map    (* map for static secret keys *)
  var mEsk       : (Sidx, Esk) map    (* map for ephemeral secret keys *)
  var mEexp      : (Sidx, Eexp) map   (* map for ephemeral exponents of sessions *)
  var mStarted   : (Sidx, Sdata2) map (* map of started sessions *)
  var mCompleted : (Sidx, Epk)   map  (* additional data for completed sessions *)

  var bad_esk_col : bool              (* esk collision with dom(mH1) *)
    (* The esk sampled in init1/resp is already in dom(mH1). Since
       dom(mH1) = sH1 u <earlier esks>, this corresponds to
       esk-earlier-esk collisions and esk-earlier-h1_a collisions *)

  var bad_esk_norev : bool            (* h1_a query without previous reveal *)

  fun init() : unit = {
    evs = [];
    test = None;
    cH1 = 0;
    cH2 = 0;
    mH1 = Map.empty;
    sH1 = FSet.empty;
    mH2 = Map.empty;
    sH2 = FSet.empty;
    mSk = Map.empty;
    mEsk = Map.empty;
    mEexp = Map.empty;
    mStarted = Map.empty;
    mCompleted = Map.empty;
    bad_esk_col = false;
    bad_esk_norev = false;
  }

  module O : AKE_Oracles = {

    fun h1(a : Sk, x : Esk) : Eexp = {
      var e : Eexp;
      e = $sample_Eexp;
      if (!in_dom (a,x) mH1) {
        mH1.[(a,x)] = e;
      } 
      return proj mH1.[(a,x)];
    }

    fun h1_a(a : Sk, x : Esk) : Eexp option = {
      var r : Eexp option = None;
      var xe : Eexp;
      if (cH1 < qH1) {
        cH1 = cH1 + 1;
        if (any (lambda i, proj mEsk.[i] = x /\
                           ! (mem (EphemeralRev (compute_psid mStarted mEexp i)) evs))
                (fdom mStarted)) {
          bad_esk_norev = true;
        }
        sH1 = add (a,x) sH1;
        xe = h1(a,x);
        r = Some(xe);
      }
      return r;
    }

    fun h2(sstring : Sstring) : Key = {
      var ke : Key;
      ke = $sample_Key;
      if (!in_dom sstring mH2) {
        mH2.[sstring] = ke;
      }
      return proj mH2.[sstring];
    }
 
    fun h2_a(sstring : Sstring) : Key option = {
      var r : Key option = None;
      var ks : Key;
      if (cH2 < qH2) {
        cH2 = cH2 + 1;
        sH2 = add sstring sH2;
        ks = h2(sstring);
        r = Some(ks);
      }
      return r;
    }

    fun init1(i : Sidx, A : Agent, B : Agent) : Epk option = {
      var pX : Epk;
      var x : Esk;
      var r : Epk option = None; 
      if (in_dom A mSk && in_dom B mSk && !in_dom i mStarted) {
        x = proj mEsk.[i];
        if (mem x (queried_esks mH1)) bad_esk_col = true;
        mEexp.[i] = h1(proj (mSk.[A]),x);
        pX = gen_epk(proj mEexp.[i]);
        mStarted.[i] = (A,B,init);
        r = Some(pX);
        evs = Start(compute_psid mStarted mEexp i)::evs;
      }
      return r;
    }

    fun resp(i : Sidx, B : Agent, A : Agent, X : Epk) : Epk option = {
      var y : Esk;
      var pY : Epk;
      var r : Epk option = None; 
      if (in_dom A mSk && in_dom B mSk && !in_dom i mStarted && !in_dom i mCompleted) {
        y = proj mEsk.[i];
        if (mem y (queried_esks mH1)) bad_esk_col = true;
        mEexp.[i] = h1(proj (mSk.[B]),y);
        pY = gen_epk(proj mEexp.[i]);
        mStarted.[i] = (B,A,resp);
        mCompleted.[i] = X;
        r = Some(pY);
        evs = Accept(compute_sid mStarted mEexp mCompleted i)::evs;
      }
      return r;
    }

    fun init2(i : Sidx, Y : Epk) : unit = {
      if (!in_dom i mCompleted && in_dom i mStarted && in_dom i mEexp) {
        mCompleted.[i] = Y;
        evs = Accept(compute_sid mStarted mEexp mCompleted i)::evs;
      }
    }

    fun staticRev(A : Agent) : Sk option = {
      var r : Sk option = None;
      if (in_dom A mSk) {
        r = mSk.[A];
        evs = StaticRev(A)::evs;
      }
      return r;
    }

    fun ephemeralRev(i : Sidx) : Esk option = {
      var r : Esk option = None;
      if (in_dom i mStarted && in_dom i mEexp) {
        r = mEsk.[i];
        evs = EphemeralRev(compute_psid mStarted mEexp i)::evs;
      }
      return r;
    }

    fun computeKey(i : Sidx) : Key option = {
      var r : Key option = None;
      var sd : Sdata2;
      var k : Key;
      if (in_dom i mCompleted && in_dom i mStarted && in_dom i mEexp) {
        sd = proj mStarted.[i];
        k = h2(gen_sstring (proj mEexp.[i]) (proj mSk.[sd2_actor sd])
                           (sd2_peer sd) (proj mCompleted.[i])
                           (sd2_role sd));
        r = Some k;
      }
      return r;
    }

    fun sessionRev(i : Sidx) : Key option = {
      var r : Key option = None;
      if (in_dom i mCompleted && in_dom i mStarted && in_dom i mEexp) {
        evs = SessionRev(compute_sid mStarted mEexp mCompleted i)::evs;
        r = computeKey(i);
      }
      return r;
    }
  }
  
  module A = FA(O)

  fun main() : bool = {
    var b : bool = def;
    var pks : Pk list = [];
    var t_idx : Sidx = def;
    var key : Key = def;
    var keyo : Key option = def;
    var b' : bool = def;
    var i : int = 0;
    var sidxs : Sidx set = univ_Sidx;
    var sidx : Sidx;
    var ska : Sk = def;
    var pka : Pk = def;

    init();
    while (i < qAgent) {
      ska = $sample_Sk;
      pka = gen_pk(ska);
      pks = pka :: pks;
      mSk.[pka] = ska;
    }

    while (sidxs <> FSet.empty) {
      sidx = pick sidxs;
      sidxs = rm sidx sidxs;
      mEsk.[sidx] = $sample_Esk;
    } 

    t_idx = A.choose(pks);
    b = ${0,1};
    if (in_dom t_idx mStarted && in_dom t_idx mCompleted && in_dom t_idx mEexp) {
      test = Some (compute_sid mStarted mEexp mCompleted t_idx);
        (* the if-condition implies "mem (Accept (proj O.test)) O.evs" *)
      if (b) {
        keyo = O.computeKey(t_idx);
      } else {
        key  = $sample_Key;
        keyo = Some key;
      }
      b' = A.guess(keyo);
    }
    return (b = b');
  }
}.

lemma Eq_AKE_2_AKE_3(A <: Adv{AKE_2, AKE_3}):
  equiv[ AKE_2(A).main ~ AKE_3(A).main : true ==>
            (res /\ test_fresh AKE_2.test AKE_2.evs /\
             !AKE_2.bad_esk_col /\ !AKE_2.bad_esk_norev){1}
         => (res /\ test_fresh AKE_3.test AKE_3.evs /\
             !AKE_3.bad_esk_col /\ !AKE_3.bad_esk_norev){2} ].
proof strict.
  admit. (* Lazy to eager random oracle *)
qed.

(* Do not query h1 in init1 and resp, instead sample Eexp and store
   it in mEexp (as before).
   For queries h1_a(a,x), check if there is i such that
     x = proj mEexp.[i] /\ proj mSk.[sd2_actor (proj mStarted.[i])].
   If yes, take this value.
   Invariant:
   .. disjoint mH1{2} and mEexp ..
   forall x a x',
     mH1{1}.[(x,a)] = Some x' <=>
     (mH1{2}.[(x,a)] = Some x' \/
      exists i, .. see above ..)
*)
module AKE_4(FA : Adv) = {
  
  var evs  : Event list               (* events for queries performed by adversary *)
  var test : Sid option               (* session id of test session *)

  var cH1, cH2 : int                  (* counters for queries *)

  var mH1 : ((Sk * Esk), Eexp) map    (* map for h1 *)
  var sH1 : (Sk * Esk) set            (* adversary queries for h1 *)

  var mH2 : (Sstring, Key) map        (* map for h2 *)
  var sH2 : Sstring set               (* adversary queries for h2 *)

  var mSk        : (Agent, Sk) map    (* map for static secret keys *)
  var mEsk       : (Sidx, Esk) map    (* map for ephemeral secret keys *)
  var mEexp      : (Sidx, Eexp) map   (* map for ephemeral exponents of sessions *)
  var mStarted   : (Sidx, Sdata2) map (* map of started sessions *)
  var mCompleted : (Sidx, Epk)   map  (* additional data for completed sessions *)

  var bad_esk_col : bool              (* esk collision with dom(mH1) *)
    (* The esk sampled in init1/resp is already in dom(mH1). Since
       dom(mH1) = sH1 u <earlier esks>, this corresponds to
       esk-earlier-esk collisions and esk-earlier-h1_a collisions *)

  var bad_esk_norev : bool            (* h1_a query without previous reveal *)

  fun init() : unit = {
    evs = [];
    test = None;
    cH1 = 0;
    cH2 = 0;
    mH1 = Map.empty;
    sH1 = FSet.empty;
    mH2 = Map.empty;
    sH2 = FSet.empty;
    mSk = Map.empty;
    mEsk = Map.empty;
    mEexp = Map.empty;
    mStarted = Map.empty;
    mCompleted = Map.empty;
    bad_esk_col = false;
    bad_esk_norev = false;
  }

  module O : AKE_Oracles = {

    fun h1(a : Sk, x : Esk) : Eexp = {
      var e : Eexp;
      e = $sample_Eexp;
      if (!in_dom (a,x) mH1) {
        mH1.[(a,x)] = e;
      } 
      return proj mH1.[(a,x)];
    }

    fun h1_a(a : Sk, x : Esk) : Eexp option = {
      var r : Eexp option = None;
      var xe : Eexp;
      if (cH1 < qH1) {
        cH1 = cH1 + 1;
        if (any (lambda i, proj mEsk.[i] = x /\
                           ! (mem (EphemeralRev (compute_psid mStarted mEexp i)) evs))
                (fdom mStarted)) {
          bad_esk_norev = true;
        }
        sH1 = add (a,x) sH1;
        xe = h1(a,x);
        r = Some(xe);
      }
      return r;
    }

    fun h2(sstring : Sstring) : Key = {
      var ke : Key;
      ke = $sample_Key;
      if (!in_dom sstring mH2) {
        mH2.[sstring] = ke;
      }
      return proj mH2.[sstring];
    }
 
    fun h2_a(sstring : Sstring) : Key option = {
      var r : Key option = None;
      var ks : Key;
      if (cH2 < qH2) {
        cH2 = cH2 + 1;
        sH2 = add sstring sH2;
        ks = h2(sstring);
        r = Some(ks);
      }
      return r;
    }

    fun init1(i : Sidx, A : Agent, B : Agent) : Epk option = {
      var pX : Epk;
      var x : Esk;
      var r : Epk option = None; 
      if (in_dom A mSk && in_dom B mSk && !in_dom i mStarted) {
        x = proj mEsk.[i];
        if (mem x (queried_esks mH1)) bad_esk_col = true;
        mEexp.[i] = h1(proj (mSk.[A]),x);
        pX = gen_epk(proj mEexp.[i]);
        mStarted.[i] = (A,B,init);
        r = Some(pX);
        evs = Start(compute_psid mStarted mEexp i)::evs;
      }
      return r;
    }

    fun resp(i : Sidx, B : Agent, A : Agent, X : Epk) : Epk option = {
      var y : Esk;
      var pY : Epk;
      var r : Epk option = None; 
      if (in_dom A mSk && in_dom B mSk && !in_dom i mStarted && !in_dom i mCompleted) {
        y = proj mEsk.[i];
        if (mem y (queried_esks mH1)) bad_esk_col = true;
        mEexp.[i] = h1(proj (mSk.[B]),y);
        pY = gen_epk(proj mEexp.[i]);
        mStarted.[i] = (B,A,resp);
        mCompleted.[i] = X;
        r = Some(pY);
        evs = Accept(compute_sid mStarted mEexp mCompleted i)::evs;
      }
      return r;
    }

    fun init2(i : Sidx, Y : Epk) : unit = {
      if (!in_dom i mCompleted && in_dom i mStarted && in_dom i mEexp) {
        mCompleted.[i] = Y;
        evs = Accept(compute_sid mStarted mEexp mCompleted i)::evs;
      }
    }

    fun staticRev(A : Agent) : Sk option = {
      var r : Sk option = None;
      if (in_dom A mSk) {
        r = mSk.[A];
        evs = StaticRev(A)::evs;
      }
      return r;
    }

    fun ephemeralRev(i : Sidx) : Esk option = {
      var r : Esk option = None;
      if (in_dom i mStarted && in_dom i mEexp) {
        r = mEsk.[i];
        evs = EphemeralRev(compute_psid mStarted mEexp i)::evs;
      }
      return r;
    }

    fun computeKey(i : Sidx) : Key option = {
      var r : Key option = None;
      var sd : Sdata2;
      var k : Key;
      if (in_dom i mCompleted && in_dom i mStarted && in_dom i mEexp) {
        sd = proj mStarted.[i];
        k = h2(gen_sstring (proj mEexp.[i]) (proj mSk.[sd2_actor sd])
                           (sd2_peer sd) (proj mCompleted.[i])
                           (sd2_role sd));
        r = Some k;
      }
      return r;
    }

    fun sessionRev(i : Sidx) : Key option = {
      var r : Key option = None;
      if (in_dom i mCompleted && in_dom i mStarted && in_dom i mEexp) {
        evs = SessionRev(compute_sid mStarted mEexp mCompleted i)::evs;
        r = computeKey(i);
      }
      return r;
    }
  }
  
  module A = FA(O)

  fun main() : bool = {
    var b : bool = def;
    var pks : Pk list = [];
    var t_idx : Sidx = def;
    var key : Key = def;
    var keyo : Key option = def;
    var b' : bool = def;
    var i : int = 0;
    var sidxs : Sidx set = univ_Sidx;
    var sidx : Sidx;
    var ska : Sk = def;
    var pka : Pk = def;

    init();
    while (i < qAgent) {
      ska = $sample_Sk;
      pka = gen_pk(ska);
      pks = pka :: pks;
      mSk.[pka] = ska;
    }

    while (sidxs <> FSet.empty) {
      sidx = pick sidxs;
      sidxs = rm sidx sidxs;
      mEsk.[sidx] = $sample_Esk;
    } 

    t_idx = A.choose(pks);
    b = ${0,1};
    if (in_dom t_idx mStarted && in_dom t_idx mCompleted && in_dom t_idx mEexp) {
      test = Some (compute_sid mStarted mEexp mCompleted t_idx);
        (* the if-condition implies "mem (Accept (proj O.test)) O.evs" *)
      if (b) {
        keyo = O.computeKey(t_idx);
      } else {
        key  = $sample_Key;
        keyo = Some key;
      }
      b' = A.guess(keyo);
    }
    return (b = b');
  }
}.

lemma Eq_AKE_2_AKE_3(A <: Adv{AKE_2, AKE_3}):
  equiv[ AKE_2(A).main ~ AKE_3(A).main : true ==>
            (res /\ test_fresh AKE_2.test AKE_2.evs /\
             !AKE_2.bad_esk_col /\ !AKE_2.bad_esk_norev){1}
         => (res /\ test_fresh AKE_3.test AKE_3.evs /\
             !AKE_3.bad_esk_col /\ !AKE_3.bad_esk_norev){2} ].
proof strict.
  admit. (* Use Interval type for domain. Lazy to eager random oracle *)
qed.

lemma Pr_AKE_1_bad(A <: Adv) &m:
       Pr[ AKE_1(A).main() @ &m : res /\ test_fresh AKE_1.test AKE_1.evs ]
  <=   Pr[ AKE_1(A).main() @ &m : res /\ test_fresh AKE_1.test AKE_1.evs /\
                                  !AKE_1.bad_esk_norev /\ !AKE_1.bad_esk_col]
     + Pr[ AKE_1(A).main() @ &m : AKE_1.bad_esk_col ]
     + Pr[ AKE_1(A).main() @ &m : (! AKE_1.bad_esk_col) /\ AKE_1.bad_esk_norev ].
proof strict.
  admit.
qed.

(*} end: Proof: Pr[ AKE : win ] <= eps + Pr[ AKE_EexpRev : win ] *)
*)