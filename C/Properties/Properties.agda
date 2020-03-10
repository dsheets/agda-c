open import C
open import C.Properties.Coalgebra
open import C.Properties.State

open import Algebra.FunctionProperties
open import Data.Bool as 𝔹 using () renaming (Bool to 𝔹)
open import Data.Empty
open import Data.Nat as ℕ using (ℕ)
open import Data.Integer as ℤ using (+_)
open import Data.Integer.Properties as ℤₚ using ()
open import Data.Product using (∃ ; _,_ ; ∃-syntax ; proj₁ ; proj₂)
open import Data.Sum
open import Data.Vec
open import Relation.Binary
open import Relation.Binary.PropositionalEquality
open import Relation.Nullary
open import Function.Nary.NonDependent
open import Size

import Level
import Codata.Colist.Bisimilarity as CoB

module C.Properties.Properties ⦃ _ : C ⦄ ⦃ _ : Semantics ⦄ where

open C.C ⦃ ... ⦄
open Semantics ⦃ ... ⦄
open ≡-Reasoning


-- EXPRESSION EQUIVALENCE

+-left-id : LeftIdentity _≅ₑ_ (⟪ + 0 ⟫) _+_
+-left-id e {E} {v} {w} 0+e⇒v e⇒w =
  let 0+e⇒0+w = +-eval (nat (+ 0)) e⇒w in
  let v≡0+w = ⊢-det 0+e⇒v 0+e⇒0+w in
  begin
    v
    ≡⟨ v≡0+w ⟩
    + 0 ℤ.+ w
    ≡⟨ ℤₚ.+-identityˡ w ⟩
    w
  ∎

+-right-id : RightIdentity _≅ₑ_ (⟪ + 0 ⟫) _+_
+-right-id e {E} {v} {w} e+0⇒v e⇒w =
  let e+0⇒w+0 = +-eval e⇒w (nat (+ 0)) in
  let v≡w+0 = ⊢-det e+0⇒v e+0⇒w+0 in
  begin
    v
    ≡⟨ v≡w+0 ⟩
    w ℤ.+ + 0
    ≡⟨ ℤₚ.+-identityʳ w ⟩
    w
  ∎

+-id : Identity _≅ₑ_ (⟪ + 0 ⟫) _+_
+-id = +-left-id , +-right-id

+-assoc : Associative _≅ₑ_ _+_
+-assoc x y z {E} {v} {w} [x+y]+z⇒v x+[y+z]⇒w =
  let x' , ⇒x' = ⊢-total {e = x} in
  let y' , ⇒y' = ⊢-total {e = y} in
  let z' , ⇒z' = ⊢-total {e = z} in
  begin
    v
    ≡⟨ ⊢-det [x+y]+z⇒v (+-eval (+-eval ⇒x' ⇒y') ⇒z') ⟩
    (x' ℤ.+ y') ℤ.+ z'
    ≡⟨ ℤₚ.+-assoc x' y' z' ⟩
    x' ℤ.+ (y' ℤ.+ z')
    ≡⟨ ⊢-det (+-eval ⇒x' (+-eval ⇒y' ⇒z')) x+[y+z]⇒w ⟩
    w
  ∎

+-comm : Commutative _≅ₑ_ _+_
+-comm x y {E} {v} {w} x+y⇒v y+x⇒w =
  let x' , ⇒x' = ⊢-total {e = x} in
  let y' , ⇒y' = ⊢-total {e = y} in
  begin
    v
    ≡⟨ ⊢-det x+y⇒v (+-eval ⇒x' ⇒y') ⟩
    x' ℤ.+ y'
    ≡⟨ ℤₚ.+-comm x' y' ⟩
    y' ℤ.+ x'
    ≡⟨ ⊢-det (+-eval ⇒y' ⇒x') y+x⇒w ⟩
    w
  ∎

-- *-id : Identity _≅ₑ_ (⟨ + 1 ⟩) _*_
-- *-zero : Zero _≅ₑ_ (⟨ + 0 ⟩) _*_
-- *-assoc : Associative _≅ₑ_ _*_
-- *-commute : Commutative _≅ₑ_ _*_
-- ∸-id : Identity _≅ₑ_ (⟨ + 0 ⟩) _-_
-- /-id : Identity _≅ₑ_ (⟨ + 1 ⟩) _/_
-- -- TODO: algebra properties of _<_ _<=_ _>_ _>=_ _==_ using standard library algebra
-- <-trans : ∀ { x y z : Expr Int } → x < y ≅ₑ true → y < z ≅ₑ true → x < z ≅ₑ true
-- ||-id : Identity _≅ₑ_ false _||_
-- ||-zero : Zero _≅ₑ_ true _||_
-- ||-assoc : Associative _≅ₑ_ _||_
-- ||-commute : Commutative _≅ₑ_ _||_
-- &&-id : Identity _≅ₑ_ true _&&_
-- &&-zero : Zero _≅ₑ_ false _&&_
-- &&-assoc : Associative _≅ₑ_ _&&_
-- &&-commute : Commutative _≅ₑ_ _&&_ 


-- PROGRAM EQUIVALENCE

L0 : ∀ { n } → Levels n
L0 {0} = _
L0 {ℕ.suc n} = Level.zero , L0

infix 0 _⊢_≅ₚ_
_⊢_≅ₚ_ : ∀ (i : Size) { n } { v : Sets n L0 } → Rel (v ⇉ Statement) Level.zero
_⊢_≅ₚ_ i {0} x y = ∀ { k E } → i ⊢ 𝒮 x k E ≅ₛ 𝒮 y k E
_⊢_≅ₚ_ i {ℕ.suc n} {_ , v} x y = ∀ { r } → _⊢_≅ₚ_ i (x r) (y r)

≅ₚ-refl : ∀ { i n } { v : Sets n L0 } → Reflexive (_⊢_≅ₚ_ i {v = v})
≅ₚ-refl {_} {ℕ.zero} {Level.lift _} {_} = ≅ₛ-refl
≅ₚ-refl {_} {ℕ.suc n} {x , v} = (≅ₚ-refl {v = v})

≅ₚ-sym : ∀ { i n } { v : Sets n L0 } → Symmetric (_⊢_≅ₚ_ i {v = v})
-- ≅ₚ-sym {_} {0} {lift} i~j = IsEquivalence.sym ≅ₛ-equiv i~j
-- ≅ₚ-sym {_} {ℕ.suc n} {x , v} i~j = ≅ₚ-sym {v = v} i~j

≅ₚ-trans : ∀ { i n } { v : Sets n L0 } → Transitive (_⊢_≅ₚ_ i {v = v})
-- ≅ₚ-trans {0} {lift} i~j j~k = IsEquivalence.trans ≅ₛ-equiv i~j j~k
-- ≅ₚ-trans {ℕ.suc n} {x , v} i~j j~k = ≅ₚ-trans {v = v} i~j j~k

≅ₚ-equiv : ∀ { i n } { v : Sets n L0 } → IsEquivalence (_⊢_≅ₚ_ i {v = v})
≅ₚ-equiv = record { refl = ≅ₚ-refl ; sym = ≅ₚ-sym ; trans = ≅ₚ-trans }

≅ₚ-setoid : ∀ { i n } { v : Sets n L0 } → Setoid _ _
≅ₚ-setoid {i} {v = v} = record {
  Carrier = v ⇉ Statement ;
  _≈_ = i ⊢_≅ₚ_ ;
  isEquivalence = ≅ₚ-equiv }

import Relation.Binary.Reasoning.Setoid as Reasoning
module ≅-Reasoning { i } = Reasoning (≅ₚ-setoid {i} {0})
  renaming (_≈⟨_⟩_ to _≅⟨_⟩_ ; _≈˘⟨_⟩_ to _≅˘⟨_⟩_)

open ≅-Reasoning
  renaming (_≡⟨⟩_ to _≡'⟨⟩_ ; begin_ to begin'_ ; _∎ to _∎')

postulate ≅ₚ-cong : ∀ { i n } { v : Sets n L0 } (f : (v ⇉ Statement) → Statement) (x y : v ⇉ Statement) → i ⊢ x ≅ₚ y → i ⊢ f x ≅ₚ f y
-- ≅ₚ-cong {v = []} {[]} f x y x≅y {k} {E} =
--   ≅ₛ-cong (λ { (𝒮 s k E) → 𝒮 (f s) k E }) (𝒮 x k E) (𝒮 y k E) x≅y
-- ≅ₚ-cong {v = α ∷ αs} {[]} f x y x≅y {k} {E} =
--   let g : (r : α) → f (λ _ → x r) ≅ₚ f (λ _ → y r)
--       g r = ≅ₚ-cong {v = αs} {[]} (λ v → f (λ _ → v)) _ _ (x≅y {r})
--   in
--     {!g ? {k} {E}!}
-- ≅ₚ-cong {v = v} {β ∷ βs} f x y x≅y {r} =
--   ≅ₚ-cong {v = v} {βs} (λ c → f c r) _ _ x≅y

postulate ；-assoc : ∀ { i } → Associative (i ⊢_≅ₚ_) _；_

β-if-true : ∀ { x y : Statement }
  → _ ⊢ (if true then x else y) ≅ₚ x
β-if-true = ↝⇒≅ₛ (↝-if-true true-eval)

β-if-false : ∀ { x y : Statement } → _ ⊢ if false then x else y ≅ₚ y
β-if-false = ↝⇒≅ₛ (↝-if-false false-eval)

η-if : ∀ { cond : Expr Bool } { e : Statement } → _ ⊢ if cond then e else e ≅ₚ e
η-if {cond}
  with ⊢-total {e = cond}
... | (𝔹.false , ⇒false) = ↝⇒≅ₛ (↝-if-false ⇒false)
... | (𝔹.true , ⇒true) = ↝⇒≅ₛ (↝-if-true ⇒true)

β-while : ∀ { e₁ : Expr Bool } { e₂ : Statement }
  → _ ⊢ while e₁ then e₂ ≅ₚ if e₁ then (e₂ ； while e₁ then e₂) else nop
β-while = ↝⇒≅ₛ ↝-while

≔-subst : ∀ { α } { x : Ref α } { e : Expr α } { f : Expr α → Statement }
  → _ ⊢ (x ≔ e ； f (★ x)) ≅ₚ (f e)
-- ≔-subst {α} {x} {e} {f} {k} {E}
--   with ⊢-total {α} {E} {e}
-- ... | v , ⇒v
--     with ≅ₛ-subst {f = f} (deref {x Env.↦ v , E} {α} {x} x↦v∈x↦v,E) ⇒v refl
-- ...   | inj₁ (A , f[★x]↝A , f[e]↝A) =
--         let reduction = ↝-seq ◅ ↝-assignment ⇒v ⟨ ? ⟩ ◅ ↝-nop ⟨ ? ⟩ ◅ ε ⟨ ? ⟩ in
--           inj₁ (A , reduction ◅◅ f[★x]↝A , f[e]↝A)
-- ...   | inj₂ (f[★x]↝ω , f[e]↝ω) =
--         let reduction = ↝-seq ◅ ↝-assignment ⇒v ⟨ ? ⟩ ◅ ↝-nop ⟨ ? ⟩ ◅ ε ⟨ ? ⟩ in
--           inj₂ (↝ω-transᵇ reduction f[★x]↝ω , f[e]↝ω)

decl-elim : ∀ { α } { f : Statement } → _ ⊢ (decl α λ x → f) ≅ₚ f
decl-elim {α} {f} = ≅ₛ-decl

nested-while-loop : ∀ { i } { s t : Statement }
  → i ⊢ s ≅ₚ t → i ⊢ while true then s ≅ₚ while true then (while true then t)
nested-while-loop {_} {s} {t} s≅t =
  begin'
    (while true then s)
    ≅⟨ ≅ₚ-cong {_} {0} (λ s → while true then s) s t s≅t ⟩
    (while true then t)
    ≅⟨ ↝⇒≅ₛ ↝-while ⟩
    (if true then (t ； while true then t) else nop)
    ≅⟨ β-if-true ⟩
    (t ； while true then t)
    ≅⟨ {!!} ⟩
    ((t ； while true then t) ； while true then (while true then t))
    ≅⟨ {!? CoB.∷ ?!} ⟩ --≅⟨ {!inj₁ (_ , ↝-seq ◅ ε ⟨ ? ⟩ , ↝-seq ◅ (↝-if-true true-eval) ⟨ ? ⟩ ◅ ε ⟨ ? ⟩)!} ⟩
    (if true then (t ； while true then t) else nop ； while true then (while true then t))
    ≅⟨ {!inj₁ (_ , ↝-seq ◅ ε ⟨ ? ⟩ , ↝-seq ◅ ↝-while ⟨ ? ⟩ ◅ ε ⟨ ? ⟩)!} ⟩
    (while true then t ； while true then (while true then t))
    ≅˘⟨ β-if-true ⟩
    (if true then (while true then t ； while true then (while true then t)) else nop)
    ≅˘⟨ ↝*⇒≅ₛ {!↝-while ◅ ε ⟨ ? ⟩!} ⟩
    (while true then (while true then t))
  ∎'

nested-while-loop' : ∀ { i } { s t : Statement } { e : Expr Bool }
  → i ⊢ s ≅ₚ t → i ⊢ while e then s ≅ₚ while e then (while e then t)
