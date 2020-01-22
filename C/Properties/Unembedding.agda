-- Based on https://www.cl.cam.ac.uk/~jdy22/papers/unembedding.pdf

module C.Properties.Unembedding where

open import C
open import Data.Nat
open import Data.Nat.Properties
open import Data.Integer as ℤ using (ℤ)
open import Data.Product
open import Data.Unit using (⊤ ; tt)
open import Data.Maybe
open import Data.Fin as 𝔽 using (Fin)
open import Data.Vec
open import Data.Bool using () renaming (Bool to 𝔹 ; true to True ; false to False)
open import Function
open import Relation.Nullary
open import Relation.Binary.PropositionalEquality

module ℐ where

  data Ctx : ∀ n → Vec c_type n → Set where
    wrap : ∀ { n } (v : Vec c_type n) → Ctx n v

  data Ref : ∀ n → Vec c_type n → c_type → Set where
    zero : ∀ { n α l } → Ref (suc n) (α ∷ l) α
    suc : ∀ { n ctx α β } → Ref n ctx α → Ref (suc n) (β ∷ ctx) α
    -- deref : Ref n Γ (Array α n) → ∀ m → Ref n Γ α

  data Op : c_type → c_type → c_type → Set where
    add sub mul div : Op Int Int Int
    lt lte gt gte eq : Op Int Int Bool
    || && : Op Bool Bool Bool

  data Expr : ∀ n → Vec c_type n → c_type → Set where
    op : ∀ { α β γ n ctx } → Op α β γ → Expr n ctx α → Expr n ctx β → Expr n ctx γ
    not : ∀ { n ctx } → Expr n ctx Bool → Expr n ctx Bool
    true false : ∀ { n ctx } → Expr n ctx Bool
    int : ∀ { n ctx } → ℤ → Expr n ctx Int
    var : ∀ { α n ctx } → Ref n ctx α → Expr n ctx α

  data Statement : ∀ n → Vec c_type n → Set where
    if : ∀ { n ctx } → Expr n ctx Bool → Statement n ctx → Statement n ctx → Statement n ctx
    assign : ∀ { α n ctx } → Ref n ctx α → Expr n ctx α → Statement n ctx
    seq : ∀ { n ctx } → Statement n ctx → Statement n ctx → Statement n ctx
    decl : ∀ { n ctx } α → Statement (suc n) (α ∷ ctx) → Statement n ctx

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

  tshift' : ∀ { α n m Γ₁ Γ₂ } → (i : ℕ) → Ctx n Γ₁ → Ctx (suc m) (α ∷ Γ₂) → i < n → Ref n Γ₁ α
  tshift' 0 (wrap (h₁ ∷ t₁)) (wrap (h₂ ∷ t₂)) _
    with compare-type h₁ h₂
  ... | yes refl = zero
  ... | no _ = {!!} -- Absurd
  tshift' (suc n) (wrap (h ∷ t)) Γ₂ (s≤s n≤m) = suc (tshift' n (wrap t) Γ₂ n≤m)

  tshift : ∀ { α n m Γ₁ Γ₂ } → Ctx (suc n) Γ₁ → Ctx (suc m) (α ∷ Γ₂) → Ref (suc n) Γ₁ α
  tshift {n = n} {m} Γ₁ Γ₂ = tshift' ((suc n) ∸ (suc m)) Γ₁ Γ₂ (s≤s (n∸m≤n m n))

  impl : C
  C.Ref impl α = ∀ n Γ → Ref n Γ α
  C.Expr impl α = ∀ n Γ → Expr n Γ α
  C.Statement impl = ∀ n Γ → Statement n Γ
  C.⟨_⟩ impl x n Γ = int x
  C._+_ impl x y n Γ = op add (x n Γ) (y n Γ)
  C._*_ impl x y n Γ = op mul (x n Γ) (y n Γ)
  C._-_ impl x y n Γ = op sub (x n Γ) (y n Γ)
  C._/_ impl x y n Γ = op div (x n Γ) (y n Γ)
  C._<_ impl x y n Γ = op lt (x n Γ) (y n Γ)
  C._<=_ impl x y n Γ = op lte (x n Γ) (y n Γ)
  C._>_ impl x y n Γ = op gt (x n Γ) (y n Γ)
  C._>=_ impl x y n Γ = op gte (x n Γ) (y n Γ)
  C._==_ impl x y n Γ = op eq (x n Γ) (y n Γ)
  C.true impl n Γ = true
  C.false impl n Γ = false
  C._||_ impl x y n Γ = op || (x n Γ) (y n Γ)
  C._&&_ impl x y n Γ = op && (x n Γ) (y n Γ)
  C.!_ impl x n Γ = not (x n Γ)
  C.if_then_else_ impl cond s₁ s₂ n Γ = if (cond n Γ) (s₁ n Γ) (s₂ n Γ)
  C._[_] impl x i n Γ = {!!}
  C.★_ impl x n Γ = var (x n Γ)
  C._≔_ impl x y n Γ = assign (x n Γ) (y n Γ)
  C._；_ impl s₁ s₂ n Γ = seq (s₁ n Γ) (s₂ n Γ)
  C.decl impl α f n Γ₁ = decl α (f v (suc n) (α ∷ Γ₁))
    where
      v : ∀ m Γ₂ → Ref m Γ₂ α
      v 0 [] = {!!}
      v (suc m) Γ₂ = tshift (wrap Γ₂) (wrap (α ∷ Γ₁))
  C.nop impl n Γ = {!!}
  (C.for impl to x then x₁) x₂ = {!!}
  (C.while impl then x) x₁ = {!!}

  data Env { impl : C } : ∀ n → Vec c_type n → Set where
    empty : Env 0 []
    extend : ∀ { n Γ α } → Env {impl} n Γ → C.Ref impl α → Env (suc n) (α ∷ Γ)

  pattern ↶⁰ = zero
  pattern ↶¹ = suc ↶⁰
  pattern ↶² = suc ↶¹
  pattern ↶³ = suc ↶²
  pattern ↶⁴ = suc ↶³
  pattern ↶⁵ = suc ↶⁴
  pattern ↶⁶ = suc ↶⁵
  pattern ↶⁷ = suc ↶⁶
  pattern ↶⁸ = suc ↶⁷
  pattern ↶⁹ = suc ↶⁸

lookupT : ∀ { impl n Γ α } → ℐ.Env {impl} n Γ → ℐ.Ref n Γ α → C.Ref impl α
lookupT (ℐ.extend _ v) ℐ.zero = v
lookupT (ℐ.extend env _) (ℐ.suc r) = lookupT env r

Expr* : ∀ n → Vec c_type n → c_type → Set₁
Expr* n Γ α = ∀ impl → ℐ.Env {impl} n Γ → C.Expr impl α

toExpr* : ∀ { n Γ α } → ℐ.Expr n Γ α → Expr* n Γ α
op₂ : ∀ { α β γ n Γ } → (∀ impl → C.Expr impl α → C.Expr impl β → C.Expr impl γ) → ℐ.Expr n Γ α → ℐ.Expr n Γ β → Expr* n Γ γ
op₂ _∙_ x y impl env = _∙_ impl (toExpr* x impl env) (toExpr* y impl env)
toExpr* (ℐ.op ℐ.add x y) = op₂ C._+_ x y
toExpr* (ℐ.op ℐ.sub x y) = op₂ C._-_ x y
toExpr* (ℐ.op ℐ.mul x y) = op₂ C._*_ x y
toExpr* (ℐ.op ℐ.div x y) = op₂ C._/_ x y
toExpr* (ℐ.op ℐ.lt x y) = op₂ C._<_ x y
toExpr* (ℐ.op ℐ.lte x y) = op₂ C._<=_ x y
toExpr* (ℐ.op ℐ.gt x y) = op₂ C._>_ x y
toExpr* (ℐ.op ℐ.gte x y) = op₂ C._>=_ x y
toExpr* (ℐ.op ℐ.eq x y) = op₂ C._==_ x y
toExpr* (ℐ.op ℐ.|| x y) = op₂ C._||_ x y
toExpr* (ℐ.op ℐ.&& x y) = op₂ C._&&_ x y
toExpr* (ℐ.not x) impl env = C.!_ impl (toExpr* x impl env)
toExpr* ℐ.true impl env = C.true impl
toExpr* ℐ.false impl env = C.false impl
toExpr* (ℐ.int n) impl env = C.⟨_⟩ impl n
toExpr* (ℐ.var x) impl env = C.★_ impl (lookupT env x)

Statement* : ∀ n → Vec c_type n → Set₁
Statement* n Γ = ∀ impl → ℐ.Env {impl} n Γ → C.Statement impl

toStatement* : ∀ { n Γ } → ℐ.Statement n Γ → Statement* n Γ
toStatement* (ℐ.if cond x y) impl env =
  C.if_then_else_ impl
    (toExpr* cond impl env)
    (toStatement* x impl env)
    (toStatement* y impl env)
toStatement* (ℐ.assign x y) impl env =
  C._≔_ impl (lookupT env x) (toExpr* y impl env)
toStatement* (ℐ.seq x y) impl env =
  C._；_ impl (toStatement* x impl env) (toStatement* y impl env)
toStatement* (ℐ.decl α f) impl env =
  C.decl impl α (λ x → toStatement* f impl (ℐ.extend env x))

convert-to : (∀ ⦃ impl ⦄ → C.Statement impl) → ℐ.Statement 0 []
convert-to s = s ⦃ ℐ.impl ⦄ 0 []

convert-from : ℐ.Statement 0 [] → (∀ ⦃ impl ⦄ → C.Statement impl)
convert-from s ⦃ impl ⦄ = toStatement* s impl ℐ.empty

open C.C ⦃ ... ⦄

_ : ℐ.Statement 0 []
_ = {!convert-to (decl Int λ x → x ≔ ★ x)!}
