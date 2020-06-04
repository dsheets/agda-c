-- Based on https://www.cl.cam.ac.uk/~jdy22/papers/unembedding.pdf

module C.Semantics.SmallStep.Properties.Unembedding where

open import C.Lang

open import Data.Bool using () renaming (Bool to 𝔹 ; true to True ; false to False)
open import Data.Empty
open import Data.Fin as 𝔽 using (Fin)
open import Data.Integer as ℤ using (ℤ)
open import Data.Maybe
open import Data.Nat
open import Data.Nat.Properties
open import Data.Product
open import Data.Unit using (⊤ ; tt)
open import Data.Vec hiding (_>>=_)
open import Function
open import Relation.Binary.PropositionalEquality
open import Relation.Nullary

data Ctx : ∀ n → Vec c_type n → Set where
  wrap : ∀ { n } (v : Vec c_type n) → Ctx n v

data Expr : ∀ n → Vec c_type n → c_type → Set

data Ref : ∀ n → Vec c_type n → c_type → Set where
  zero : ∀ { n α l } → Ref (suc n) (α ∷ l) α
  suc : ∀ { n ctx α β } → Ref n ctx α → Ref (suc n) (β ∷ ctx) α
  index : ∀ { n ctx α m } → Ref n ctx (Array α m) → Expr n ctx Int → Ref n ctx α

ref-contra : ∀ { α } → Ref 0 [] α → ⊥
ref-contra (index r i) = ref-contra r

refs-lemma : ∀ { n Γ α } (r : Ref n Γ α) → 0 < n
refs-lemma zero = s≤s z≤n
refs-lemma (suc r) = s≤s z≤n
refs-lemma (index r x) = refs-lemma r

compare-type : ∀ (α β : c_type) → Dec (α ≡ β)
compare-type Int Int = yes refl
compare-type Int Bool = no (λ ())
compare-type Int (Array β n) = no (λ ())
compare-type Bool Int = no (λ ())
compare-type Bool Bool = yes refl
compare-type Bool (Array β n) = no (λ ())
compare-type (Array α n) Int = no (λ ())
compare-type (Array α n) Bool = no (λ ())
compare-type (Array α n) (Array β m)
  with compare-type α β | n ≟ m
... | yes refl | yes refl = yes refl
... | yes refl | no ¬p    = no λ { refl → ¬p refl }
... | no ¬p    | _        = no λ { refl → ¬p refl }

tshift' : ∀ { α n m Γ₁ Γ₂ } → (i : ℕ) → Ctx n Γ₁ → Ctx (suc m) (α ∷ Γ₂) → i < n → Maybe (Ref n Γ₁ α)
tshift' 0 (wrap (h₁ ∷ t₁)) (wrap (α ∷ _)) _
  with compare-type h₁ α
... | yes refl = just zero
... | no _ = nothing
tshift' (suc n) (wrap (h ∷ t)) Γ₂ (s≤s n≤m) = tshift' n (wrap t) Γ₂ n≤m >>= λ x → just (suc x)

tshift : ∀ { α n m Γ₁ Γ₂ } → Ctx (suc n) Γ₁ → Ctx (suc m) (α ∷ Γ₂) → Maybe (Ref (suc n) Γ₁ α)
tshift {n = n} {m} Γ₁ Γ₂ = tshift' ((suc n) ∸ (suc m)) Γ₁ Γ₂ (s≤s (n∸m≤n m n))

data Op : c_type → c_type → c_type → Set where
  add sub mul div : Op Int Int Int
  lt lte gt gte eq : Op Int Int Bool
  || && : Op Bool Bool Bool

data Expr where
  op : ∀ { α β γ n Γ } → Op α β γ → Expr n Γ α → Expr n Γ β → Expr n Γ γ
  not : ∀ { n Γ } → Expr n Γ Bool → Expr n Γ Bool
  true false : ∀ { n Γ } → Expr n Γ Bool
  int : ∀ { n Γ } → ℤ → Expr n Γ Int
  var : ∀ { α n Γ } → Ref n Γ α → Expr n Γ α
  tenary : ∀ { α n Γ } → Expr n Γ Bool → Expr n Γ α → Expr n Γ α → Expr n Γ α

data Statement : ∀ n → Vec c_type n → Set where
  if : ∀ { n Γ } → Expr n Γ Bool → Statement n Γ → Statement n Γ → Statement n Γ
  assign : ∀ { α n Γ } → Ref n Γ α → Expr n Γ α → Statement n Γ
  seq : ∀ { n Γ } → Statement n Γ → Statement n Γ → Statement n Γ
  decl : ∀ { n Γ } α → Statement (suc n) (α ∷ Γ) → Statement n Γ
  nop : ∀ { n Γ } → Statement n Γ
  for : ∀ { n Γ } → Expr n Γ Int → Expr n Γ Int → Statement (suc n) (Int ∷ Γ) → Statement n Γ
  while : ∀ { n Γ } → Expr n Γ Bool → Statement n Γ → Statement n Γ
  putchar : ∀ { n Γ } → Expr n Γ Int → Statement n Γ

impl : Lang
Lang.Ref impl α = ∀ n Γ → Maybe (Ref n Γ α)
Lang.Expr impl α = ∀ n Γ → Maybe (Expr n Γ α)
Lang.Statement impl = ∀ n Γ → Maybe (Statement n Γ)
Lang.⟪_⟫ impl x n Γ = just (int x)
Lang._+_ impl x y n Γ =
  x n Γ >>= λ x →
    y n Γ >>= λ y →
      just (op add x y)
Lang._*_ impl x y n Γ =
  x n Γ >>= λ x →
    y n Γ >>= λ y →
      just (op mul x y)
Lang._-_ impl x y n Γ =
  x n Γ >>= λ x →
    y n Γ >>= λ y →
      just (op sub x y)
Lang._/_ impl x y n Γ =
  x n Γ >>= λ x →
    y n Γ >>= λ y →
      just (op div x y)
Lang._<_ impl x y n Γ =
  x n Γ >>= λ x →
    y n Γ >>= λ y →
      just (op lt x y)
Lang._<=_ impl x y n Γ =
  x n Γ >>= λ x →
    y n Γ >>= λ y →
      just (op lte x y)
Lang._>_ impl x y n Γ =
  x n Γ >>= λ x →
    y n Γ >>= λ y →
      just (op gt x y)
Lang._>=_ impl x y n Γ =
  x n Γ >>= λ x →
    y n Γ >>= λ y →
      just (op gte x y)
Lang._==_ impl x y n Γ =
  x n Γ >>= λ x →
    y n Γ >>= λ y →
      just (op eq x y)
Lang.true impl n Γ = just true
Lang.false impl n Γ = just false
Lang._||_ impl x y n Γ =
  x n Γ >>= λ x →
    y n Γ >>= λ y →
      just (op || x y)
Lang._&&_ impl x y n Γ =
  x n Γ >>= λ x →
    y n Γ >>= λ y →
      just (op && x y)
Lang.!_ impl x n Γ =
  x n Γ >>= λ x →
    just (not x)
Lang._⁇_∷_ impl e x y n Γ =
  e n Γ >>= λ e →
    x n Γ >>= λ x →
      y n Γ >>= λ y →
        just (tenary e x y)
Lang.if_then_else_ impl cond s₁ s₂ n Γ =
  cond n Γ >>= λ cond →
    s₁ n Γ >>= λ s₁ →
      s₂ n Γ >>= λ s₂ →
        just (if cond s₁ s₂)
Lang._[_] impl x i n Γ =
  x n Γ >>= λ x →
    i n Γ >>= λ i →
      just (index x i)
Lang.★_ impl x n Γ =
  x n Γ >>= λ x →
    just (var x)
Lang._≔_ impl x y n Γ =
  x n Γ >>= λ x →
    y n Γ >>= λ y →
      just (assign x y)
Lang._；_ impl s₁ s₂ n Γ =
  s₁ n Γ >>= λ s₁ →
    s₂ n Γ >>= λ s₂ →
      just (seq s₁ s₂)
Lang.decl impl α f n Γ₁ =
  f v (suc n) (α ∷ Γ₁) >>= λ f →
    just (decl α f)
  where
    v : Lang.Ref impl α
    v 0 _ = nothing
    v (suc m) Γ₂ = tshift (wrap Γ₂) (wrap (α ∷ Γ₁))
Lang.nop impl n Γ = just nop
Lang.for_to_then_ impl l u f n Γ₁ =
  l n Γ₁ >>= λ l →
    u n Γ₁ >>= λ u →
      f v (suc n) (Int ∷ Γ₁) >>= λ f →
        just (for l u f)
  where
    v : Lang.Ref impl Int
    v 0 _ = nothing
    v (suc m) Γ₂ = tshift (wrap Γ₂) (wrap (Int ∷ Γ₁))
Lang.while_then_ impl e s n Γ =
  e n Γ >>= λ e →
    s n Γ >>= λ s →
      just (while e s)
Lang.putchar impl e n Γ =
  e n Γ >>= λ e →
    just (putchar e)

data Env { impl : Lang } : ∀ n → Vec c_type n → Set where
  empty : Env 0 []
  extend : ∀ { n Γ α } → Env {impl} n Γ → Lang.Ref impl α → Env (suc n) (α ∷ Γ)

Expr* : ∀ n → Vec c_type n → c_type → Set₁
Expr* n Γ α = ∀ impl → Env {impl} n Γ → Lang.Expr impl α

toExpr* : ∀ { n Γ α } → Expr n Γ α → Expr* n Γ α

lookupT : ∀ { impl n Γ α } → Env {impl} n Γ → Ref n Γ α → Lang.Ref impl α
lookupT (extend _ v) zero = v
lookupT (extend env _) (suc r) = lookupT env r
lookupT {impl} E (index r i) = Lang._[_] impl (lookupT E r) (toExpr* i impl E)

op₂ : ∀ { α β γ n Γ } → (∀ impl → Lang.Expr impl α → Lang.Expr impl β → Lang.Expr impl γ) → Expr n Γ α → Expr n Γ β → Expr* n Γ γ
op₂ _∙_ x y impl env = _∙_ impl (toExpr* x impl env) (toExpr* y impl env)
toExpr* (op add x y) = op₂ Lang._+_ x y
toExpr* (op sub x y) = op₂ Lang._-_ x y
toExpr* (op mul x y) = op₂ Lang._*_ x y
toExpr* (op div x y) = op₂ Lang._/_ x y
toExpr* (op lt x y) = op₂ Lang._<_ x y
toExpr* (op lte x y) = op₂ Lang._<=_ x y
toExpr* (op gt x y) = op₂ Lang._>_ x y
toExpr* (op gte x y) = op₂ Lang._>=_ x y
toExpr* (op eq x y) = op₂ Lang._==_ x y
toExpr* (op || x y) = op₂ Lang._||_ x y
toExpr* (op && x y) = op₂ Lang._&&_ x y
toExpr* (not x) impl env = Lang.!_ impl (toExpr* x impl env)
toExpr* true impl env = Lang.true impl
toExpr* false impl env = Lang.false impl
toExpr* (int n) impl env = Lang.⟪_⟫ impl n
toExpr* (var x) impl env = Lang.★_ impl (lookupT env x)
toExpr* (tenary e x y) impl env =
  Lang._⁇_∷_ impl (toExpr* e impl env) (toExpr* x impl env) (toExpr* y impl env)

Statement* : ∀ n → Vec c_type n → Set₁
Statement* n Γ = ∀ impl → Env {impl} n Γ → Lang.Statement impl

toStatement* : ∀ { n Γ } → Statement n Γ → Statement* n Γ
toStatement* (if cond x y) impl env =
  Lang.if_then_else_ impl
    (toExpr* cond impl env)
    (toStatement* x impl env)
    (toStatement* y impl env)
toStatement* (assign x y) impl env =
  Lang._≔_ impl (lookupT env x) (toExpr* y impl env)
toStatement* (seq x y) impl env =
  Lang._；_ impl (toStatement* x impl env) (toStatement* y impl env)
toStatement* (decl α f) impl env =
  Lang.decl impl α (λ x → toStatement* f impl (extend env x))
toStatement* nop impl env = Lang.nop impl
toStatement* (for l u f) impl env =
  Lang.for_to_then_ impl
    (toExpr* l impl env)
    (toExpr* u impl env)
    (λ r → toStatement* f impl (extend env r))
toStatement* (while e s) impl env =
  Lang.while_then_ impl (toExpr* e impl env) (toStatement* s impl env)
toStatement* (putchar e) impl env = Lang.putchar impl (toExpr* e impl env)

convert-to : (∀ ⦃ impl ⦄ → Lang.Statement impl) → Lang.Statement impl
convert-to s = s ⦃ impl ⦄

convert-from : Lang.Statement impl → (∀ ⦃ impl ⦄ → Lang.Statement impl)
convert-from s ⦃ impl ⦄
  with s 0 []
... | nothing = Lang.nop impl -- TODO
... | just s' = toStatement* s' impl empty

pattern ↶⁰ = Ref.zero
pattern ↶¹ = Ref.suc ↶⁰
pattern ↶² = Ref.suc ↶¹
pattern ↶³ = Ref.suc ↶²
pattern ↶⁴ = Ref.suc ↶³
pattern ↶⁵ = Ref.suc ↶⁴
pattern ↶⁶ = Ref.suc ↶⁵
pattern ↶⁷ = Ref.suc ↶⁶
pattern ↶⁸ = Ref.suc ↶⁷
pattern ↶⁹ = Ref.suc ↶⁸

-- open Lang.C ⦃ ... ⦄

-- bad : Lang.Statement impl
-- bad = s ⦃ impl ⦄ v
--   where
--     s : ∀ ⦃ impl ⦄ → Lang.Ref impl Int → Lang.Statement impl
--     s ⦃ impl ⦄ r = while (Lang._<_ impl (★ r) ⟪ ℤ.+ 0 ⟫) then Lang.nop impl
--     v : Lang.Ref impl Int
--     v 0 [] = nothing
--     v (suc n) (Int ∷ Γ) = just zero
--     v (suc n) (Bool ∷ Γ) = nothing
--     v (suc n) (Array x n₁ ∷ Γ) = nothing

-- _ = {!bad 1 (Int ∷ [])!}
-- _ = {!convert-from bad !}
