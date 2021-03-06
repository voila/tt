(** Normalization of expressions. *)

open Syntax
open Context

let lookup k env = List.nth env k

let extend env = None :: env

let env_of_ctx ctx = List.map (function Parameter _ -> None | Definition (_, e) -> Some e) ctx.decls

(** [norm env e] evaluates expression [e] in environment [env] to a weak head normal form,
    while [norm ~weak:false env e] evaluates to normal form. *)
let norm ?(weak=false) =
  let rec norm env ((e', loc) as e) =
    match e' with
      | Var k ->
        (match lookup k env with
          | None -> e
          | Some e -> norm env e)
      | Universe _ -> e
      | Pi (x, t1, t2) ->
        if weak
        then e
        else mk_pi x (norm env t1) (norm (extend env) t2)
      | Lambda (x, t, e') -> 
        if weak
        then e
        else mk_lambda x (norm env t) (norm (extend env) e')
      | Subst (s, e) -> norm env (subst s e)
      | App (e1, e2) ->
        let (e1', _) as e1 = norm env e1 in
          (match e1' with
            | Lambda (x, _, e) -> norm env (mk_subst (Dot (e2, idsubst)) e)
            | Var _ | App _ -> 
              let e2 = (if weak then e2 else norm env e2) in 
                App (e1, e2), loc
            | Subst _ | Universe _ | Pi _ | Ascribe _ -> Error.runtime ~loc:(snd e2) "Function expected")
      | Ascribe (e, _) -> norm env e
  in
    norm

(** [nf ctx e] computes the normal form of expression [e]. *)
let nf ctx = norm ~weak:false (env_of_ctx ctx)

(** [whnf ctx e] computes the weak head normal form of expression [e]. *)
let whnf ctx = norm ~weak:true (env_of_ctx ctx)

