module Interpreter (interpret, Comparable) where

import Algorithm
import Control.Monad.Free
import Control.Comonad.Cofree
import Operation
import Diff
import Syntax
import Data.Map
import Patch
import SES
import Term

hylo :: Functor f => (t -> f b -> b) -> (a -> (t, f a)) -> a -> b
hylo down up a = down annotation $ hylo down up <$> syntax where
  (annotation, syntax) = up a

constructAndRun :: (Eq a, Eq annotation) => Comparable a annotation -> Term a annotation -> Term a annotation -> Maybe (Diff a annotation)
constructAndRun _ a b | a == b = hylo introduce eliminate <$> zipTerms a b where
  eliminate :: Cofree f a -> (a, f (Cofree f a))
  eliminate (extract :< unwrap) = (extract, unwrap)
  introduce :: (annotation, annotation) -> Syntax a (Diff a annotation) -> Diff a annotation
  introduce ann syntax = Free $ Annotated ann syntax
constructAndRun comparable a b | not $ comparable a b = Nothing
constructAndRun comparable (annotation1 :< a) (annotation2 :< b) =
  run comparable $ algorithm a b where
    algorithm (Indexed a) (Indexed b) = Free $ ByIndex a b (Pure . Free . Annotated (annotation1, annotation2) . Indexed)
    algorithm (Keyed a) (Keyed b) = Free $ ByKey a b (Pure . Free . Annotated (annotation1, annotation2) . Keyed)
    algorithm (Leaf a) (Leaf b) | a == b = Pure . Free . Annotated (annotation1, annotation2) $ Leaf b
    algorithm a b = Free $ Recursive (annotation1 :< a) (annotation2 :< b) Pure

run :: (Eq a, Eq annotation) => Comparable a annotation -> Algorithm a annotation (Diff a annotation) -> Maybe (Diff a annotation)
run _ (Pure diff) = Just diff

run comparable (Free (Recursive (annotation1 :< a) (annotation2 :< b) f)) = run comparable . f $ recur a b where
  recur (Indexed a') (Indexed b') | length a' == length b' =
    Free . Annotated (annotation1, annotation2) . Indexed $ zipWith (interpret comparable) a' b'
  recur (Fixed a') (Fixed b') | length a' == length b' =
    Free . Annotated (annotation1, annotation2) . Fixed $ zipWith (interpret comparable) a' b'
  recur (Keyed a') (Keyed b') | keys a' == keys b' =
    Free . Annotated (annotation1, annotation2) . Keyed . fromList . fmap repack $ keys b' where
      repack key = (key, interpretInBoth key a' b')
      interpretInBoth key a' b' = maybeInterpret (Data.Map.lookup key a') (Data.Map.lookup key b')
      maybeInterpret (Just a) (Just b) = interpret comparable a b
  recur _ _ = Pure $ Replace (annotation1 :< a) (annotation2 :< b)

run comparable (Free (ByKey a b f)) = run comparable $ f byKey where
  byKey = unions [ deleted, inserted, patched ]
  deleted = (Pure . Delete) <$> difference a b
  inserted = (Pure . Insert) <$> difference b a
  patched = intersectionWith (interpret comparable) a b

run comparable (Free (ByIndex a b f)) = run comparable . f $ ses (constructAndRun comparable) cost a b

type Comparable a annotation = Term a annotation -> Term a annotation -> Bool

interpret :: (Eq a, Eq annotation) => Comparable a annotation -> Term a annotation -> Term a annotation -> Diff a annotation
interpret comparable a b = maybeReplace $ constructAndRun comparable a b where
  maybeReplace (Just a) = a
  maybeReplace Nothing = Pure $ Replace a b
