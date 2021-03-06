type name = string

let eq_name n1 n2 = (n1 = n2)

(* types *)
type ty =
  | K of name
  | Arrow of ty * ty

(* new type generator *)
let gen_type =
  let v = ref 0 in
  incr v;
  K (string_of_int !v)

let rec eq_typ t1 t2 =
  match t1, t2 with
  | K (n1), K (n2) -> eq_name n1 n2
  | Arrow (ty11, ty12), Arrow (ty21, ty22) ->
    eq_typ ty11 ty21 && eq_typ ty12 ty22
  | _ -> false

(* typing context *)
type context = ty list

let get_type_c i c = List.nth c (i-1)

(* lambda terms *)
type term =
  | Var  of int
  | XVar of name
  | Abs  of ty * term
  | App  of term * term

(* lambda height *)
let rec height (t : term) (n : int) =
  match t with
  | Var(_) -> n
  | XVar(_) -> n
  | Abs(ty, t) -> height t (n+1)
  | App(t1, t2) -> max (height t1 n) (height t2 n)

let rec lift (t : term) (i : int) =
  match t with
  | Var(n) -> if n > i then Var(n+1) else t
  | XVar(_) -> t
  | Abs(ty, t) -> Abs(ty, lift t (i+1))
  | App(t1, t2) -> App((lift t1 i), (lift t2 i))

(* lift (up arrow) operation : increments free de brujin indices *)
let lift_plus (t : term) = lift t 0

(* substitution for beta reduction *)
let rec subst (a: term) (b: term) (n: int) =
  match a with
  | Var(m) -> if m > n then Var(n-1)
    else (if n = m then b else Var(m))
  | XVar(_) -> a
  | Abs(ty, t1) -> Abs(ty, subst t1 (lift_plus b) (n+1))
  | App(t1, t2) -> App((subst t1 b n), (subst t2 b n))

(* beta reduction *)
let beta_red (t: term) =
  match t with
  | App(Abs(ty, a), b) -> subst a b 1
  | _ -> t

(* count free variables *)
let rec free_var (t : term) (i : int) =
  match t with
  | Var(m) -> if m > i then 1 else 0
  | XVar(_) -> 0
  | Abs(ty, t1) -> free_var t1 (i+1)
  | App(t1, t2) -> (free_var t1 i) + (free_var t2 i)

(*------------------------------ lsgima --------------------------------*)

(* lambda sigma substitutions and terms *)
type s_subst =
  (*| Yvar of name *)
  | Id
  | Shift
  | Cons of s_term * s_subst
  | Comp of s_subst * s_subst
and s_term =
  | S_One
  | S_Xvar of name
  | S_App of s_term * s_term
  | S_Abs of ty * s_term
  | S_Tsub of s_term * s_subst

let gen_new_XVar () =
  let truc = ref 0 in
  incr truc;
  "X" ^ (string_of_int !truc)

(* n number : One lifted (n-1) times *)
let rec s_shift_n (n : int) =
  match n with
  | 0 -> Id
  | 1 -> Shift
  | n -> Comp(Shift, s_shift_n (n-1))

(* lambda terms to lambda sigma terms *)
let rec precooking (l_t : term) (n : int) : s_term =
  match l_t with
  | Var(k) -> S_Tsub (S_One, s_shift_n (k-1)) (* Var k *)
  | XVar(nam) -> S_Tsub (S_Xvar(nam), s_shift_n (n))
  | Abs(ty, t1) -> S_Abs(ty, precooking t1 (n+1))
  | App(t1, t2) -> S_App((precooking t1 n), (precooking t2 n))

exception No_unshift

(* for eta : need to reverse shift operation *)
let rec unshift_s (t : s_term) = (* not sure what i am doing here *)
  match t with
  | S_One          -> raise No_unshift
  | S_Xvar (n)     -> S_Xvar (n)
  | S_App (t1, t2) -> S_App (unshift_s t1, unshift_s t2)
  | S_Abs (ty, t)  -> S_Abs (ty, unshift_s t)
  | S_Tsub (t, s)  -> S_Tsub (t, (unshift_sub_s s))
and unshift_sub_s (s : s_subst) =
  match s with
  | Id            -> Id
  | Shift         -> Id
  | Cons (t, s)   -> Cons (t, s)
  | Comp (s1, s2) -> if s2 = Shift
                     then s1
                     else unshift_sub_s s2

(* check if term is a de brujin indice *)
let rec is_number t =
  match t with
  | S_One         -> true
  | S_Tsub (t, s) -> if s = Shift
                     then is_number t
                     else if t = S_One
                          then is_shift_n s
                          else false
  | _ -> false
and is_shift_n s =
  match s with
  | Shift         -> true
  | Comp (s1, s2) -> (is_shift_n s1) && (is_shift_n s2)
  | _ -> false

let add_option_i o1 i =
  match o1 with
  | Some (n) -> Some (n+i)
  | None -> None

let add_option o1 o2 =
  match o1,o2 with
  | Some (n1), Some (n2) -> Some (n1+n2)
  | _ -> None

(* get the integer corresponding to a term representing a de brujin indice *)
let rec get_number t =
  match t with
  | S_One         -> Some(1)
  | S_Tsub (t, s) -> if s = Shift
                     then add_option_i (get_number t) 1
                     else if t = S_One
                          then add_option_i (count_shift s) 1
                          else None
  | _ -> None
and count_shift s =
  match s with
  | Shift         -> Some(1)
  | Comp (s1, s2) -> add_option (count_shift s1) (count_shift s2)
  | _ -> None

(* pretty print *)
let rec print_sigma_term t =
  match t with
  | S_One          -> print_string "1"
  | S_Xvar (n)     -> print_string n
  | S_Abs (ty, t)  -> print_string "λ.( "; print_sigma_term t;
                      print_string " )"
  | S_App (t1, t2) -> print_string "( "; print_sigma_term t1;
                      print_string " ";
                      print_sigma_term t2; print_string " )"
  | S_Tsub (t1, s) -> let o_i = get_number t in
                      match o_i with
                        | None ->
                          print_string "( ";
                          print_sigma_term t1; print_string " [ ";
                          print_sigma_subst s; print_string " ] )"
                        | Some (i) ->
                          print_int i
and print_sigma_subst s =
  match s with
  | Id             -> print_string "id"
  | Shift          -> print_string "↑"
  | Cons (t1, s2)  -> print_sigma_term t1;
                      print_string "."; print_sigma_subst s2
  | Comp (s1, s2)  -> print_sigma_subst s1;
                      print_string "∘"; print_sigma_subst s2

(* reduction rules *)
let beta_red_s (t: s_term) =
  match t with
  | S_App (S_Abs (ty, a), b) -> S_Tsub (a, Cons (b, Id))
  | _ -> t

let app_red_s (t: s_term) =
  match t with
  | S_Tsub (S_App (a,b), s) -> S_App (S_Tsub (a,s), S_Tsub (b,s))
  | _ -> t

let varcons_red_s (t: s_term) =
  match t with
  | S_Tsub (S_One, Cons (a,b)) -> a
  | _ -> t

let id_red_s (t: s_term) =
  match t with
  | S_Tsub (a, Id) -> a
  | _ -> t

let abs_red_s (t: s_term) =
  match t with
  | S_Tsub (S_Abs (ty, a), s) -> S_Abs (ty, S_Tsub (a, Cons (S_One, Comp (s, Shift))))
  | _ -> t

let clos_red_s (t: s_term) =
  match t with
  | S_Tsub (S_Tsub (a,s),t) -> S_Tsub (a, Comp (s,t))
  | _ -> t

let idl_red_s (s: s_subst) =
  match s with
  | Comp (Id, s1) -> s1
  | _ -> s

let shiftcons_red_s (s: s_subst) =
  match s with
  | Comp (Shift, Cons (a,s1)) -> s1
  | _ -> s

let assenv_red_s (s: s_subst) =
  match s with
  | Comp (Comp (s1, s2), s3) -> Comp (s1, Comp (s2,s3))
  | _ -> s

let mapenv_red_s (s: s_subst) =
  match s with
  | Comp (Cons (a,s1),t) -> Cons (S_Tsub (a,t), Comp (s1,t))
  | _ -> s

let idr_red_s (s: s_subst) =
  match s with
  | Comp (s1, Id) -> s1
  | _ -> s

let varshift_red_s (s: s_subst) =
  match s with
  | Cons (S_One, Shift) -> Id
  | _ -> s

let scons_red_s (s: s_subst) =
  match s with
  | Cons (S_Tsub (S_One, s1), Comp (Shift, s2)) -> if s1 = s2 then s1 else s
  | _ -> s

let eta_red_s (t: s_term) =
  match t with
  | S_Abs (ty, S_App(a, S_One)) -> unshift_s a
  | _ -> t

(* All reduction rules for terms *)
let reduce_term_s (t : s_term) =
  match t with
  | S_Tsub (S_App (a,b), s) -> S_App (S_Tsub (a,s), S_Tsub (b,s))
  | S_Tsub (S_One, Cons (a,b)) -> a
  | S_Tsub (a, Id) -> a
  | S_Tsub (S_Abs (ty, a), s) -> S_Abs (ty, S_Tsub (a, Cons (S_One, Comp (s, Shift))))
  | S_Tsub (S_Tsub (a,s),t) -> S_Tsub (a, Comp (s,t))
  | _ -> t

(* All reduction rules for subst *)
let reduce_subst_s (s : s_subst) =
  match s with
  | Comp (Id, s1) -> s1
  | Comp (Shift, Cons (a,s1)) -> s1
  | Comp (Comp (s1, s2), s3) -> Comp (s1, Comp (s2,s3))
  | Comp (Cons (a,s1),t) -> Cons (S_Tsub (a,t), Comp (s1,t))
  | Comp (s1, Id) -> s1
  | Cons (S_One, Shift) -> Id
  | Cons (S_Tsub (S_One, s1), Comp (Shift, s2)) -> if s1 = s2 then s1 else s
  | _ -> s

(* Attempt to leftmost outermost application of function on lambda sigma *)
let rec transform_term (t : s_term) (f : s_term -> s_term) (g : s_subst -> s_subst) : s_term =
  let transformed_term = f t in
  match transformed_term with
    | S_One          -> S_One
    | S_Xvar (n)     -> S_Xvar (n)
    | S_Abs (ty, t)  -> S_Abs (ty, transform_term t f g)
    | S_App (t1, t2) -> let leftmost = transform_term t1 f g in
                        if leftmost = t1
                        then S_App (t1, transform_term t2 f g)
                        else S_App (transform_term leftmost f g, t2)
    | S_Tsub (t1, s) -> S_Tsub (transform_term t1 f g, transform_subst s f g)
and transform_subst (s : s_subst) (f : s_term -> s_term) (g : s_subst -> s_subst) : s_subst =
  let transformed_subst = g s in
  match transformed_subst with
    | Id            -> Id
    | Shift         -> Shift
    | Cons (t1, s2) -> Cons (transform_term t1 f g, transform_subst s2 f g)
    | Comp (s1, s2) -> let leftmost = transform_subst s1 f g in
                       if leftmost = s1
                       then Comp (s1, transform_subst s2 f g)
                       else Comp (transform_subst leftmost f g, s2)

(* normalisation with lambda calculus *)
let rec normalise_beta_eta (t : s_term) =
  let reduced = transform_term t (beta_red_s) (fun x -> x) in
  let reduced = transform_term reduced (eta_red_s) (fun x -> x) in
  if reduced <> t then
    normalise_beta_eta reduced
  else
    reduced

(* term and subst rewriting for sigma calculus *)
let rec normalise_sigma (t : s_term) =
    let reduced = transform_term t reduce_term_s reduce_subst_s in
    if reduced <> t then
      normalise_sigma reduced
    else
      reduced

(* normalisation for lambda sigma calculus *)
let rec normalise_lambda_sigma (t : s_term) =
  let reduced = normalise_beta_eta t in
  let reduced = normalise_sigma reduced in
  let reduced = normalise_beta_eta reduced in
  if reduced <> t then
    normalise_lambda_sigma reduced
  else
    reduced

let two = S_Tsub (S_One, Shift)

let three = S_Tsub (two, Shift)

let four = S_Tsub (three, Shift)

let test = S_App (three, S_Tsub (S_App ( four, S_Xvar ("H1") ), Cons (S_One, Id ) ) )

let () = print_sigma_term test; print_string "\n"; print_sigma_term (normalise_lambda_sigma test)

(* number of arrow in a type *)
let rec length_type (t : ty) =
  match t with
  | K(n) -> 1
  | Arrow(t1, t2) -> length_type t1 + length_type t2
(* FIXME : maybe wrong for getting "toplevel" arrow chain size, cf. number of Ai for long normal form p. 19 dowek1 *)

exception No_inference

module Map_str = Map.Make (String)
type meta_var_str = (ty * bool) Map_str.t
                       
let rec type_check_inf (c: context)  t_term (m_c : meta_var_str) =
  match t_term with
  | S_One -> get_type_c 1 c
  | S_Xvar(n) -> fst (Map_str.find n m_c)  (* FIXME : Not really sure about this one, should be an unique type Tx AND an unique context Cx, cf. dowek1 p18*)
  | S_Abs(ty_abs, te_abs) ->
    type_check_inf (ty_abs::c) te_abs m_c
  | S_App(a, b) -> let ty_A = type_check_inf c b m_c in
    let ty_arr = type_check_inf c a m_c in
    (match ty_arr with
     | Arrow(ty_A2, ty_B) -> if eq_typ ty_A ty_A2 then ty_B else raise No_inference
     | _ -> raise No_inference)
  | S_Tsub(t, s) -> let c_s = type_check_cont c s m_c in
    type_check_inf c_s t m_c 
and type_check_cont c t_sub m_c =
  match t_sub with
  (*| Yvar(n)      -> *) (* TODO : Do not remember why this variant was added. Removed for the moment *)
  | Id           -> c
  | Shift        -> (match c with
      | []     -> raise No_inference
      | hd::tl -> tl)
  | Cons(t, s)   -> let c_s = type_check_cont c s m_c in
    let ty_t = type_check_inf c t m_c in
    ty_t::c_s
  | Comp(s1, s2) -> let c_s2 = type_check_cont c s2 m_c in
    type_check_cont c_s2 s1 m_c 


(* eta long normal form *)
(* auxialiary function to get the last type before the returning type of a type *)
(* the first element of the returning pair is the type you wan't and the second is the type without the result that you get *) 
let rec get_before_last_type (typ : ty) : (ty*ty) =
  match typ with
  | K n -> failwith "TODO make a good comment to say it's not possible :p"
  | Arrow (ty1,K n) -> (ty1, K n)
  | Arrow (ty1,ty2) -> let (ret1,ret2) =  get_before_last_type ty2 in
                       (ret1,Arrow (ty1,ret2))

let rec apply_fun_subst (s : s_subst) (f : s_term -> s_term) : s_subst =
  match s with
  | Id | Shift -> s
  | Cons (t,s1) -> Cons (f t, apply_fun_subst s f) 
  | Comp (s1,s2) -> Comp(apply_fun_subst s1 f,apply_fun_subst s2 f)
                        
(* dans cette fonction on considère que l'on appel avec un terme qui à est déja sous normale forme 
c'est pour ça par exemple quand dans le cas de S_Tsub on ne traite que le cas où le terme de gauche est une variable existentielle *)
let rec eta_long_normal_form (t : s_term) (typ : ty) (m_c : meta_var_str) : s_term =
  match t with
  | S_One | S_Xvar _ | S_Tsub (_,_) -> t
  | S_App (t1,t2) -> let (ty,rest) = get_before_last_type typ in
                     let left = (match t1 with
                       | S_One -> S_Tsub (S_One,(s_shift_n 2))
                       | S_Tsub(S_One,s1) -> S_Tsub(S_One,Comp(Shift,s1))
                       | S_Tsub(S_Xvar n,s1) ->
                          let meta_type = fst (Map_str.find n m_c) in 
                          let s_prime = apply_fun_subst s1 (fun t -> eta_long_normal_form t meta_type m_c) in S_Tsub(S_Xvar n,s_prime)
                       | _ -> failwith "eta_long_normal_form can't happend you should be in normal form") in
                     let right = eta_long_normal_form (normalise_lambda_sigma (S_Tsub(t2,(s_shift_n 1)))) rest m_c in 
                     S_Abs(ty,S_App(left,right))
  | S_Abs (ty1,t1) ->
     S_Abs(ty1,eta_long_normal_form t1 typ m_c)
                        
                                       

(*--------------------------------- Unification ------------------------------*)
(* Cette retourne les variables dont le type est soit un type atomique égal a ty ou un type flèche qui termine par un type égal à ty*)
let rec get_last_type (typ : ty) = 
  match typ with 
  | K(n) -> typ
  | Arrow (t1,t2) -> get_last_type t2

let rec find_var_end_typ_rec (cx : context) (typ : ty) (acc : int) : (ty * int) list =
  match cx with
  | t :: tl -> let last_typ = get_last_type t in
    if eq_typ last_typ typ then
      (t, acc) :: find_var_end_typ_rec tl typ (acc + 1)
    else
      find_var_end_typ_rec tl typ (acc + 1)
  | [] -> []

let find_var_end_typ (cx : context) (typ : ty) : (ty * int) list =
  find_var_end_typ_rec cx typ 1

type equa = 
  | DecEq of s_term * s_term
  | Exp

type and_list = equa list

type unif_rules_ret =
  | Ret of (and_list * meta_var_str) list
  | Rep of name * s_term * and_list
  | Nope
  | Fail

let rec get_type_without_end (typ : ty) =
  match typ with
  | K(x) -> failwith "impossible get type without end"
  | Arrow (a, K(n)) -> a
  | Arrow (a, b) -> Arrow(a, get_type_without_end b)

let rec pretty_print_list (l : 'a list) (p : 'a -> unit) =
  match l with
  | [] -> ()
  | e :: tl -> p e; print_string ":";pretty_print_list tl p

(* let print_meta_var (ctx : meta_var_str) = *)
(*   Map_str.iter (fun x e -> print_string x; print_string  *)
                                      
                     
let rec and_list_pretty_print (l : and_list) =
  match l with
  | [] -> ()
  | DecEq (s1,s2) :: tl-> print_sigma_term s1; print_string " = " ;print_sigma_term s2 ;print_string "\n";and_list_pretty_print tl
  | Exp :: tl-> print_string "Exp";and_list_pretty_print tl



let print_unif_rules_ret (u : unif_rules_ret) =
  match u with
  | Ret ((al,_) :: tl) -> and_list_pretty_print al 
  | Ret [] -> failwith "lol"
  | Rep _ -> print_string "replace"
  | Nope -> print_string "replace"
  | Fail -> print_string "fail"

                                                         
let rec al_mv_l_to_mvl (l : ((and_list * meta_var_str) list)) : meta_var_str list =
  match l with
  | [] -> []
  | (a,b) :: tl -> b :: al_mv_l_to_mvl tl

let rec al_mv_l_to_al (l : ((and_list * meta_var_str) list)) : and_list list =
  match l with
  | [] -> []
  | (a,b) :: tl -> a :: al_mv_l_to_al tl

                         
                    
                    
                    
let rec create_disjunctions (xvar : s_term) (ct : context) (ctx: meta_var_str) (l : (ty * int) list) : unif_rules_ret =
match l with
| [] -> Nope
| (t, i) :: tl -> let (new_ctx, ter) = 
                    (match t with
                    | K(n) -> (ctx, S_Tsub (S_One, s_shift_n i))
                    | Arrow (t1, t2) -> let new_name = gen_new_XVar() in
                                        let new_xvar = S_Xvar (new_name) in
                                        let new_ty = get_type_without_end t in
                                        let new_ctx = Map_str.add new_name (new_ty, false) ctx in
                                        (new_ctx, S_App (S_Tsub (S_One, s_shift_n i), new_xvar) ) ) in
                    let new_equa = DecEq (xvar, ter) in
                    Ret(([new_equa], new_ctx) :: (match create_disjunctions xvar ct ctx tl with
                                                    | Ret res -> res
                                                    | _ -> []))

let unif_rules (e: equa) (ct : context) (ctx: meta_var_str) : unif_rules_ret =
  match e with
  (* DEC LAM *)
  | DecEq (S_Abs (typ1, t1), S_Abs (typ2, t2)) -> let () = Printf.printf "Dec Lam\n " in
     if eq_typ typ1 typ2 then Ret [([ DecEq (t1, t2)], ctx)] else Fail
  (* DEC APP *)
  | DecEq (S_App (t1, t2), S_App (t3, t4)) -> let () = Printf.printf "Dec App\n " in
    if t1 = t3 then Ret [([DecEq (t2, t4)], ctx)]
      else Fail
  (* REP *)
  | DecEq (S_Xvar (n), t) -> let () = Printf.printf "Rep\n " in
                             Rep (n, t, [e])
  (* EXP APP *)
  | DecEq (S_Tsub (S_Xvar(x), s), t) -> let () = Printf.printf "Exp App\n " in
    let (typ, _) = Map_str.find x ctx in
    let lst = find_var_end_typ ct typ in
    create_disjunctions (S_Xvar (x)) ct ctx lst
  (* EXP LAM*)
  | Exp -> let () = Printf.printf "Exp Lam\n " in
     let arrow_metavars =
            Map_str.filter(fun k tb -> match tb with
                                | Arrow (_,_), false -> true 
                                | _ -> false) ctx in
         if Map_str.cardinal arrow_metavars != 0
         then 
            let (x, (typ, _)) = Map_str.min_binding arrow_metavars in
            let first_ty, rest_ty = (match typ with
              | Arrow (a, b) -> a, b
              | _ -> failwith "impossible") in 
            let name_y = gen_new_XVar() in
            let new_ctx = Map_str.add name_y (rest_ty, false) ctx in
            Ret [([DecEq(S_Xvar(x), S_Abs(first_ty, S_Xvar(name_y)))], new_ctx)]
         else
            Nope
 | _ -> Nope

type unif_ret =
  | FullNope
  | Failed
  | OneRet


let rec look_res_list (res_liste : unif_rules_ret list) : unif_ret =
  match res_liste with
    | Fail :: tl -> Failed
    | Ret _ :: tl -> OneRet
    | _ -> failwith "lol"

(* su will be a list to store the results of the pasts call of the unification function *)
(* we should have use array instead of list to represent the and_list cause now we are obligated to keep it 
 *)
(* enfaite dans su dès que on a eu un résultat on stocke la and list resulstante pour faire d'une pierre de coup *)
(* la question c'est esque on vas garder les replaces dans les résultats *)


(* pour savoir si c'est finis il suffit de regarder si toutes les variables dans le meta_var_str sont a true *)
let rec is_that_finished (ctx : meta_var_str) : bool =
  not (Map_str.exists (fun k (t,b) -> b = false) ctx)

(* il faudra que cette fonction mette à true la variable qui est bonne *)
let rec put_metaVar_true (n : name) (ctx : meta_var_str) : meta_var_str =
  let (t,_) = Map_str.find n ctx in
  let new_ctx = Map_str.remove n ctx in
  Map_str.add n (t,true) new_ctx 

let rec grafting_metaVar (n : name) (t : s_term) (tsubst : s_term) : s_term =
  match t with
  | S_One -> S_One               
  | S_Xvar n2 -> if n = n2 then tsubst else S_Xvar n2
  | S_App (t1,t2) -> S_App (grafting_metaVar n t1 tsubst,grafting_metaVar n t2 tsubst)
  | S_Abs (typ,t1) -> S_Abs(typ,grafting_metaVar n t1 tsubst)
  | S_Tsub (t1,s) -> S_Tsub(grafting_metaVar n t1 tsubst,s)
              
(* this function substitute the XVar by the term in the list *)
let rec replace_and_list (n : name) (t : s_term) (s : and_list) : and_list =
  match s with
  | [] -> []
  | e :: tl -> (match e with
               | DecEq (s1,s2) -> DecEq (s1,grafting_metaVar n s2 t) :: replace_and_list n t tl
               | Exp -> replace_and_list n t tl
               )


                                                         
                                                         
                 
let rec start_unification_list (l : ((and_list*meta_var_str) list)) (ct : context)
                               (su : (and_list * unif_rules_ret list)) : ((and_list*meta_var_str) list) option =
  match l with
  | [] -> None
  | (al,ctx) :: tl -> let res =
                    (match start_unification_list tl ct su with
                    | None -> []                                
                    | Some r -> r) in
                      (match unification_rec al su ctx ct with
                       | Some res2 -> Some (res2 @ res)
                       | None -> Some res)
                        
and unification_rec (s: and_list) (su : (and_list * unif_rules_ret list))
                    (ctx : meta_var_str) (ct : context) : ((and_list * meta_var_str) list) option =
  let () = and_list_pretty_print s in   
  if is_that_finished ctx then Some [(s,ctx)]
  else
    let (old_liste, ret_liste) = su in
    (match s with
     | [] -> (match look_res_list ret_liste with 
              | FullNope -> (match unif_rules Exp ct ctx with
                             | Ret l -> start_unification_list l ct su
                             | Rep (res_name,res_term,res_s) -> unification_rec (replace_and_list res_name res_term (old_liste @ res_s)) 
                                                                                   ([],[])
                                                                                (put_metaVar_true res_name ctx)
                                                                                ct 
                             | Nope -> None
                             | Fail -> None)                           
              | OneRet -> unification_rec (fst su) ([],[]) ctx ct
              | Failed -> None)
     | a :: tl ->
        let (old_liste, ret_liste) = su in
        let ret = unif_rules a ct ctx in
        (* todo ICI il faut faire un match sur ret pour traiter tous les cas et récupérer le nouveau ctx de metavariables *)
        let new_su = (old_liste @ [a] ,ret_liste @ [ret]) in
        (match ret with  (* unification_rec tl new_su *)
        | Ret l -> start_unification_list l ct new_su
        | Rep (res_name,res_term,res_s) -> unification_rec (replace_and_list res_name res_term (old_liste @ res_s)) 
                                                                                   ([],[])
                                                                                (put_metaVar_true res_name ctx)
                                                                                ct 
        | Nope -> None
        | Fail -> None))


      
let unification (s: and_list) (ctx : meta_var_str) (ct : context) : (meta_var_str list*(and_list list)) option =
  match unification_rec s ([],[]) ctx ct with
  | None -> None
  | Some res -> Some (al_mv_l_to_mvl res,(al_mv_l_to_al res))


      
(*   | S_One
  | S_Xvar of name
  | S_App of s_term * s_term
  | S_Abs of ty * s_term
  | S_Tsub of s_term * s_subst

type ty =
  | K of name
  | Arrow of ty * ty
                                                         
S_App (three, S_Tsub (S_App ( four, S_Xvar ("H1") ), Cons (S_One, Id ) ) )
let two = S_Tsub (S_One, Shift)                                                         *)
let () = Printf.printf "\nStarting unification tests \n"
let test1_equa = [DecEq(S_Xvar "X", S_Abs(K "int",S_One))]
let test1_ctx = Map_str.add "X" (Arrow(K "int",K "int"),false) Map_str.empty
let test1_ct = []
let () = print_string "\n start test1 \n"
let run_test1 = unification test1_equa test1_ctx test1_ct

let () =
  match run_test1 with
  | Some (a,b) -> pretty_print_list b and_list_pretty_print;()
  | None -> ()
let () = print_string "\n end test1 \n"


let test2_equa = [DecEq(S_Abs(K "int",S_Xvar "X"), S_Abs(K "int",S_One))]
let test2_ctx = Map_str.add "X" (K "int",false) Map_str.empty
let test2_ct = []
let () = print_string "\n start test2 \n"
let run_test2 = unification test2_equa test2_ctx test2_ct

let () =
  match run_test2 with
  | Some (a,b) -> pretty_print_list b and_list_pretty_print;()
  | None -> ()
let () = print_string "\n end test2 \n"



let test3_equa = [DecEq(S_Abs(K "int",S_Tsub (S_Xvar "X",s_shift_n 2)), S_Abs(K "int",S_Tsub(S_One,s_shift_n 2)))]
let test3_ctx = Map_str.add "X" (Arrow (K "a",K "a"),false) Map_str.empty
let test3_ct = [(K "a")]
let () = print_string "\n start test3 \n"
let run_test3 = unification test3_equa test3_ctx test3_ct
let () =
  match run_test3 with
  | Some (a,b) -> pretty_print_list b and_list_pretty_print;()
  | None -> ()
let () = print_string "\n end test3 \n"
                       
    
    
      
