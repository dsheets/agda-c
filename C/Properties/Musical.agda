open import Algebra.FunctionProperties
open import C.Base
open import C.Properties.State
open import Codata.Musical.Colist hiding ([_])
open import Codata.Musical.Notation
open import Data.Maybe
open import Data.Product
open import Data.Sum
open import Function
open import Relation.Binary
open import Relation.Binary.PropositionalEquality
open import Relation.Nullary
open import Relation.Nullary.Decidable

import Level
import Data.Integer as ℤ
import Data.Integer.DivMod as ℤ÷
import Data.Nat as ℕ
import Data.Bool as 𝔹

open C ⦃ ... ⦄

module C.Properties.Musical ⦃ _ : C ⦄ where

-- Based on:
-- Coinductive Verification of Program Optimizations Using Similarity Relations by Glesner et al.
-- Undecidability of Equality for Codata Types by Berger and Setzner

data SideEffect : Set where
  _↦_ : ∀ { α } → Ref α → ⟦ α ⟧ → SideEffect
  emit : ⟦ Int ⟧ → SideEffect

data Label : Set where
  τ : Label
  _↗ : SideEffect → Label

data Reduction (_~[_]↝_ : State → Label → State → Set) (A : State) : Set where
  [] : Reduction _~[_]↝_ A
  _∷_ : ∀ { B α } → A ~[ α ]↝ B → ∞ (Reduction _~[_]↝_ B) → Reduction _~[_]↝_ A

reduce : ∀ (step : State → Maybe (Label × State)) X
  → Reduction (λ A e B → step A ≡ just (e , B)) X
reduce step X = helper (λ A e B → step A ≡ just (e , B)) step X (λ A B e → id)
  where
    helper : ∀ _~[_]↝_ (step : State → Maybe (Label × State)) X
      → (∀ X Y e → step X ≡ just (e , Y) → (X ~[ e ]↝ Y))
      → Reduction _~[_]↝_ X
    helper _~[_]↝_ step X p
      with step X | p X
    ... | nothing | _ = []
    ... | just (l , S) | f = f S l refl ∷ ♯ (helper _~[_]↝_ step S p)

SideEffects : Set
SideEffects = Colist SideEffect

Labels : Set
Labels = Colist Label

labels-of : ∀ { R A } → Reduction R A → Labels
labels-of [] = []
labels-of (_∷_ {α = α} h t) = α ∷ ♯ (labels-of (♭ t))

{-# NON_TERMINATING #-} -- May have no side-effects, forever...
effects-of : ∀ { R A } → Reduction R A → SideEffects
effects-of [] = []
effects-of (_∷_ {α = τ} h t) = effects-of (♭ t)
effects-of (_∷_ {α = e ↗} h t) = e ∷ ♯ (effects-of (♭ t))

{-# NON_TERMINATING #-} -- May have no side-effects, forever...
labels-to-effects : Labels → SideEffects
labels-to-effects [] = []
labels-to-effects (τ ∷ t) = labels-to-effects (♭ t)
labels-to-effects ((x ↗) ∷ t) = x ∷ ♯ (labels-to-effects (♭ t))

data Bisim { a } { A : Set a } : Colist A → Colist A → Set a where
  [] : Bisim [] []
  _∷_ : ∀ { x y xs ys } → x ≡ y → ∞ (Bisim (♭ xs) (♭ ys)) → Bisim (x ∷ xs) (y ∷ ys)

data SmallStep* (_~[_]↝_ : State → Label → State → Set) : State → State → Labels → Set where
  ε : ∀ { X } → SmallStep* _~[_]↝_ X X []
  _◅_ : ∀ { X Y Z e es } → X ~[ e ]↝ Y → ∞ (SmallStep* _~[_]↝_ Y Z (♭ es))
    → SmallStep* _~[_]↝_ X Z (e ∷ es)

data SmallStep⁺ (_~[_]↝_ : State → Label → State → Set) : State → State → Labels → Set where
  [_] : ∀ { X Y e } → X ~[ e ]↝ Y  → SmallStep⁺ _~[_]↝_ X Y (e ∷ ♯ [])
  _∷_ : ∀ { X Y Z e es } → X ~[ e ]↝ Y → ∞ (SmallStep⁺ _~[_]↝_ Y Z (♭ es))
    → SmallStep⁺ _~[_]↝_ X Z (e ∷ es)

Congruence : ∀ { a l } { A : Set a } → Rel A l → Set _
Congruence {A = A} _~_ = ∀ (f : A → A) x y → x ~ y → (f x) ~ (f y)

record Semantics : Set₁ where
  field
    eval : ∀ { α } → Env → Expr α → ⟦ α ⟧
    step : State → Maybe (Label × State)

  _⊢_⇒_ : ∀ { α } → Env → Expr α → ⟦ α ⟧ → Set
  E ⊢ e ⇒ v = (eval E e) ≡ v

  _~[_]↝_ : State → Label → State → Set
  X ~[ e ]↝ Y = (step X) ≡ just (e , Y)

  _~[_]↝*_ : State → Labels → State → Set
  X ~[ e ]↝* Y = SmallStep* _~[_]↝_ X Y e
  
  _~[_]↝⁺_ : State → Labels → State → Set
  X ~[ e ]↝⁺ Y = SmallStep⁺ _~[_]↝_ X Y e

  field
    ⊢-total : ∀ { α E } { e : Expr α } → ∃[ v ] (E ⊢ e ⇒ v)
    ⊢-det : ∀ { α E } { e : Expr α } { v w : ⟦ α ⟧ } → E ⊢ e ⇒ v → E ⊢ e ⇒ w → v ≡ w 
    ⊢-weakening : ∀ { E E' α β } { e : Expr α } { v : ⟦ α ⟧ } { x : Ref β } { w : ⟦ β ⟧ }
      → { _ : x ∉nv E × x ∉nv E' }
      → (E ⊕ E') ⊢ e ⇒ v → (E ⊕ (x Env.↦ w , ε) ⊕ E') ⊢ e ⇒ v
    ⊢-exchange : ∀ { E E' α β γ } { x : Ref α } { y : Ref β }
      → { v : ⟦ α ⟧ } { w : ⟦ β ⟧ } { e : Expr γ } { ev : ⟦ γ ⟧ }
      → (E ⊕ (x Env.↦ v , (y Env.↦ w , ε)) ⊕ E') ⊢ e ⇒ ev
      → (E ⊕ (y Env.↦ w , (x Env.↦ v , ε)) ⊕ E') ⊢ e ⇒ ev
    -- TODO: variants on Env constructor
    nat : ∀ { E } n → E ⊢ ⟪ n ⟫ ⇒ n
    deref : ∀ { E α } { x : Ref α } { v : ⟦ α ⟧ }
      → x ↦ v ∈nv E → (E ⊢ (★ x) ⇒ v)
    +-eval : ∀ { E x y x' y' }
      → E ⊢ x ⇒ x' → E ⊢ y ⇒ y'
      → E ⊢ x + y ⇒ (x' ℤ.+ y')
    *-eval : ∀ { E x y x' y' }
      → E ⊢ x ⇒ x' → E ⊢ y ⇒ y'
      → E ⊢ x * y ⇒ (x' ℤ.* y')
    ∸-eval : ∀ { E x y x' y' }
      → E ⊢ x ⇒ x' → E ⊢ y ⇒ y'
      → E ⊢ x - y ⇒ (x' ℤ.- y')
    /-eval : ∀ { E x y x' y' }
      → E ⊢ x ⇒ x' → E ⊢ y ⇒ y' → (y≠0 : False (ℤ.∣ y' ∣ ℕ.≟ 0))
      → E ⊢ x / y ⇒ ((x' ℤ÷.div y') {y≠0})
    true-eval : ∀ { E } → E ⊢ true ⇒ 𝔹.true
    false-eval : ∀ { E } → E ⊢ false ⇒ 𝔹.false
    ||-eval : ∀ { E x y x' y' }
      → E ⊢ x ⇒ x' → E ⊢ y ⇒ y' → E ⊢ x || y ⇒ (x' 𝔹.∨ y')
    &&-eval : ∀ { E x y x' y' }
      → E ⊢ x ⇒ x' → E ⊢ y ⇒ y' → E ⊢ x && y ⇒ (x' 𝔹.∧ y')
    ⁇-eval-t : ∀ { E c α } { x y : Expr α } { x' }
      → E ⊢ c ⇒ 𝔹.true → E ⊢ x ⇒ x' → E ⊢ c ⁇ x ∷ y ⇒ x'
    ⁇-eval-f : ∀ { E c α } { x y : Expr α } { y' }
      → E ⊢ c ⇒ 𝔹.false → E ⊢ y ⇒ y' → E ⊢ c ⁇ x ∷ y ⇒ y'

    ↝-if-true : ∀ { E k } { cond : Expr Bool } { s₁ s₂ : Statement }
      → E ⊢ cond ⇒ 𝔹.true → 𝒮 (if cond then s₁ else s₂) k E ~[ τ ]↝ 𝒮 s₁ k E
    ↝-if-false : ∀ { E k } { cond : Expr Bool } { s₁ s₂ : Statement }
      → E ⊢ cond ⇒ 𝔹.false → 𝒮 (if cond then s₁ else s₂) k E ~[ τ ]↝ 𝒮 s₂ k E
    ↝-assignment : ∀ { E k α } { id : Ref α } { e : Expr α } { v : ⟦ α ⟧ }
      → E ⊢ e ⇒ v → 𝒮 (id ≔ e) k E ~[ τ ]↝ 𝒮 nop k (id Env.↦ v , E)
    ↝-seq : ∀ { E k } { s₁ s₂ : Statement }
      → 𝒮 (s₁ ； s₂) k E ~[ τ ]↝ 𝒮 s₁ (s₂ then k) E
    ↝-decl : ∀ { E k α } { f : Ref α → Statement }
      → ∃ λ (x : Ref α) → (x ∉nv E) × (𝒮 (decl α f) k E ~[ τ ]↝ 𝒮 (f x) k (x , E))
    ↝-nop : ∀ { E k } { s : Statement } → 𝒮 nop (s then k) E ~[ τ ]↝ 𝒮 s k E
    ↝-stuck : ∀ { E } → ¬ ∃[ S' ] (𝒮 nop stop E ~[ τ ]↝ S')
    ↝-for : ∀ { E k } { l u : Expr Int } { f : Ref Int → Statement } { x : Ref Int }
      → 𝒮 (for l to u then f) k E
        ~[ τ ]↝ 𝒮 (if (l < u) then (
                (decl Int λ i → i ≔ l ； f i) ；
                for (l + ⟪ ℤ.+ 1 ⟫) to u then f)
             else nop) k E
    ↝-while : ∀ { E k } { e : Expr Bool } { s : Statement }
      → 𝒮 (while e then s) k E ~[ τ ]↝ 𝒮 (if e then (s ； while e then s) else nop) k E
    ↝-putchar : ∀ { E k } { e : Expr Int } { v : ℤ.ℤ }
      → E ⊢ e ⇒ v → 𝒮 (putchar e) k E ~[ emit v ↗ ]↝ 𝒮 nop k E
    ↝-det : ∀ { S S₁ S₂ e f } → S ~[ e ]↝ S₁ → S ~[ f ]↝ S₂ → e ≡ f × S₁ ≡ S₂
    ↝-progress : ∀ (x k E) → (x ≡ nop × k ≡ stop) ⊎ (∃[ S' ] (𝒮 x k E ~[ τ ]↝ S'))


  infix 0 _≅ₑ_
  _≅ₑ_ : ∀ { α } → Rel (Expr α) Level.zero
  _≅ₑ_ { α } x y = ∀ { E : Env } { v w : ⟦ α ⟧ }
    → (E ⊢ x ⇒ v) → (E ⊢ y ⇒ w) → (v ≡ w)

  Stuck : State → Set
  Stuck S = ∀ S' e → ¬ (S ~[ e ]↝ S')

  Terminating : State → Set
  Terminating S = ∃[ S' ] ∃[ es ] (S ~[ es ]↝* S' × Stuck S')

  infix 0 _≅ₛ_
  _≅ₛ_ : Rel State Level.zero
  X ≅ₛ Y = Bisim (effects-of (reduce step X)) (effects-of (reduce step Y))

  field
    ≅ₛ-subst :
      ∀ { α E₁ E₂ k } { v w : ⟦ α ⟧ } { f : Expr α → Statement } { e₁ e₂ : Expr α }
      → E₁ ⊢ e₁ ⇒ v → E₂ ⊢ e₂ ⇒ w → v ≡ w
      → 𝒮 (f e₁) k E₁ ≅ₛ 𝒮 (f e₂) k E₂
    ≅ₛ-decl : ∀ { α f k E } → 𝒮 (decl α λ x → f) k E ≅ₛ 𝒮 f k E
    ≅ₛ-cong : Congruence _≅ₛ_


  -- EXPRESSION EQUIVALENCE

  ≅ₑ-refl : ∀ { α } → Reflexive (_≅ₑ_ {α})
  ≅ₑ-refl ⇒v ⇒w = ⊢-det ⇒v ⇒w

  ≅ₑ-sym : ∀ { α } → Symmetric (_≅ₑ_ {α})
  ≅ₑ-sym i≅j ⇒v ⇒w = sym (i≅j ⇒w ⇒v)

  ≅ₑ-trans : ∀ { α } → Transitive (_≅ₑ_ {α})
  ≅ₑ-trans i≅j j≅k ⇒v ⇒w =
    let _ , ⇒a = ⊢-total in
      trans (i≅j ⇒v ⇒a) (j≅k ⇒a ⇒w)

  ≅ₑ-equiv : ∀ { α } → IsEquivalence (_≅ₑ_ {α})
  ≅ₑ-equiv = record { refl = ≅ₑ-refl ; sym = ≅ₑ-sym ; trans = ≅ₑ-trans }


  -- REDUCTION LEMMAS

  ↝*-trans : ∀ { e f } → Trans (_~[ e ]↝*_) (_~[ f ]↝*_) (_~[ e ++ f ]↝*_)
  ↝*-trans ε j↝*k = j↝*k
  ↝*-trans (i↝X ◅ X↝*j) j↝*k = i↝X ◅ ♯ (↝*-trans (♭ X↝*j) j↝*k)

  ↝*-to-↝⁺ : ∀ { A B C e f es } → A ~[ e ]↝ B → B ~[ f ]↝* C → Bisim (e ∷ es) (e ∷ ♯ f)
    → A ~[ e ∷ es ]↝⁺ C
  ↝*-to-↝⁺ {f = []} {es} A↝B ε (refl ∷ p) with ♭ es | ♭ p
  ... | [] | [] = {!SmallStep⁺.[ A↝B ]!}
  ... | _ ∷ _ | ()
  ↝*-to-↝⁺ {f = x ∷ xs} A↝B (x₁ ◅ x₃) (refl ∷ x₂) = {!!}

  -- ↝⁺-to-↝* : ∀ { A B es } → A ~[ es ]↝⁺ B → A ~[ es ]↝* B

  -- ↝̸-transᵇ : ∀ { S S' : State } { e }
  --   → S ~[ e ]↝* S' → Terminating S' → Terminating S

  -- ↝̸-transᶠ : ∀ { S S' : State } { e }
  --   → S ~[ e ]↝* S' → Terminating S → Terminating S'

  -- ↝ω-transᵇ : ∀ { X Y : State } { e }
  --   → X ~[ e ]↝* Y → ¬ Terminating Y → ¬ Terminating X

  -- ↝ω-transᶠ : ∀ { X Y : State } { e }
  --   → X ~[ e ]↝* Y → ¬ Terminating X → ¬ Terminating Y

  -- ↝*-det : ∀ { S S₁ S₂ x y }
  --   → Stuck S₁ → Stuck S₂ → S ~[ x ]↝* S₁ → S ~[ y ]↝* S₂ → S₁ ≡ S₂

  -- ↝*-det' : ∀ { S S₁ S₂ x y }
  --   → S ~[ x ]↝* S₁ → S ~[ y ]↝* S₂ → ∃[ z ] (S₁ ~[ z ]↝* S₂ ⊎ S₂ ~[ z ]↝* S₁)

  -- ≅ₛ-refl : Reflexive _≅ₛ_
  -- ≅ₛ-sym : Symmetric _≅ₛ_
  -- ≅ₛ-trans : Transitive _≅ₛ_
  -- ≅ₛ-equiv : IsEquivalence _≅ₛ_
  -- ≅ₛ-equiv = record { refl = ≅ₛ-refl ; sym = ≅ₛ-sym ; trans = ≅ₛ-trans }

  -- ↝⇒≅ₛ : ∀ { A B } → A ~[ τ ]↝ B → A ≅ₛ B
  -- ↝*⇒≅ₛ : ∀ { A B } → A ~[ [] ]↝* B → A ≅ₛ B
