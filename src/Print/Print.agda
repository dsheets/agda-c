module Print.Print where

open import C
open import Data.List as List using (List ; [] ; _∷_)
open import Data.Maybe
open import Data.Nat as ℕ using (ℕ ; suc)
open import Data.Product
open import Data.String
open import Function using (_∘_)
open import Relation.Binary.PropositionalEquality
open import Relation.Nullary

import Data.Integer as ℤ
import Data.Nat.Show as ℕs
import Data.Char as Char

open Lang ⦃ ... ⦄

print-ctype : c_type → String
print-ctype Int = "int"
print-ctype Bool = "int"
print-ctype (Array α n) = "(" ++ (print-ctype α) ++ ")[" ++ (ℕs.show n) ++ "]" 

Print-C : Lang
Lang.Ref Print-C _ = String
Lang.Expr Print-C _ = String
Lang.Statement Print-C = ℕ → ℕ × String
Lang.⟪_⟫ Print-C x = ℤ.show x
Lang._+_ Print-C x y = "(" ++ x ++ ") + (" ++ y ++ ")"
Lang._*_ Print-C x y = "(" ++ x ++ ") * (" ++ y ++ ")"
Lang._-_ Print-C x y = "(" ++ x ++ ") - (" ++ y ++ ")"
Lang._/_ Print-C x y = "(" ++ x ++ ") / (" ++ y ++ ")"
Lang._<_ Print-C x y = "(" ++ x ++ ") < (" ++ y ++ ")"
Lang._<=_ Print-C x y = "(" ++ x ++ ") <= (" ++ y ++ ")"
Lang._>_ Print-C x y = "(" ++ x ++ ") > (" ++ y ++ ")"
Lang._>=_ Print-C x y = "(" ++ x ++ ") >= (" ++ y ++ ")"
Lang._==_ Print-C x y = "(" ++ x ++ ") == (" ++ y ++ ")"
Lang.true Print-C = "1"
Lang.false Print-C = "0"
Lang._||_ Print-C x y = "(" ++ x ++ ") || (" ++ y ++ ")"
Lang._&&_ Print-C x y = "(" ++ x ++ ") && (" ++ y ++ ")"
Lang.!_ Print-C x = "!(" ++ x ++ ")"
Lang._[_] Print-C r i = r ++ "[" ++ i ++ "]"
Lang.★_ Print-C x = x
Lang._⁇_∷_ Print-C c x y = "(" ++ c ++ ") " ++ fromChar (Char.fromℕ 63) -- Question mark = 63
    ++ " (" ++ x ++ ") : (" ++ y ++ ")"
Lang._≔_ Print-C x y n = n , x ++ " = " ++ y ++ ";\n"
Lang.if_then_else_ Print-C e x y n =
  let n , x = x n in
  let n , y = y n in
    n , "if (" ++ e ++ ") {\n" ++ x ++ "}\nelse\n{\n" ++ y ++ "}\n"
Lang._；_ Print-C x y n =
  let n , x = x n in
  let n , y = y n in
    n , x ++ y
Lang.decl Print-C α f n =
  let ref = "x" ++ ℕs.show n in
  let n , f = f ref (ℕ.suc n) in
    n , builder α ref ++ ";\n" ++ f
  where
    builder : c_type → String → String
    builder Int acc = "int " ++ acc
    builder Bool acc = "/* BOOL */ int " ++ acc
    builder (Array α n) acc = builder α (acc ++ "[" ++ ℕs.show n ++ "]")
Lang.nop Print-C n = n , ""
Lang.for_to_then_ Print-C l u f n =
  let i = "x" ++ ℕs.show n in
  let n , f = f i (ℕ.suc n) in
    n ,
    "for (int " ++ i ++ " = " ++ l ++ "; "
      ++ i ++ " <= " ++ u ++ "; "
      ++ "++" ++ i ++ ") {\n"
      ++ f
    ++ "}\n"
Lang.while_then_ Print-C e f n =
  let n , f = f n in
    n , "while (" ++ e ++ "){\n" ++ f ++ "}\n"
Lang.putchar Print-C x n = n , "putchar(" ++ x ++ ");\n"

print : (∀ ⦃ _ : Lang ⦄ → Statement) → String
print s = proj₂ (s ⦃ Print-C ⦄ 0)

print-main : (∀ ⦃ _ : Lang ⦄ → Statement) → String
print-main s =
  "#include <stdio.h>\n"
  ++ "int main(void) {\n"
    ++ print s
    ++ "return 0;\n"
 ++ "}\n"

