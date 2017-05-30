{-# LANGUAGE DataKinds, GADTs, GeneralizedNewtypeDeriving, MultiParamTypeClasses, StandaloneDeriving, TypeOperators #-}
module Renderer
( DiffRenderer(..)
, TermRenderer(..)
, renderPatch
, renderSExpressionDiff
, renderSExpressionTerm
, renderJSONDiff
, renderJSONTerm
, renderToC
, declarationAlgebra
, identifierAlgebra
, Summaries(..)
, File(..)
) where

import Data.Aeson (Value, (.=))
import qualified Data.Map as Map
import Data.Syntax.Algebra (RAlgebra)
import Diff (SyntaxDiff)
import Info (DefaultFields)
import Prologue
import Renderer.JSON as R
import Renderer.Patch as R
import Renderer.SExpression as R
import Renderer.TOC as R
import Syntax as S
import Term (SyntaxTerm)

data DiffRenderer output where
  PatchDiffRenderer :: DiffRenderer File
  ToCDiffRenderer :: DiffRenderer Summaries
  JSONDiffRenderer :: DiffRenderer (Map.Map Text Value)
  SExpressionDiffRenderer :: DiffRenderer ByteString
  IdentityDiffRenderer :: DiffRenderer (SyntaxDiff Text (Maybe Declaration ': DefaultFields))

deriving instance Eq (DiffRenderer output)
deriving instance Show (DiffRenderer output)

data TermRenderer output where
  JSONTermRenderer :: TermRenderer [Value]
  SExpressionTermRenderer :: TermRenderer ByteString
  IdentityTermRenderer :: TermRenderer (Maybe (SyntaxTerm Text DefaultFields))

deriving instance Eq (TermRenderer output)
deriving instance Show (TermRenderer output)


identifierAlgebra :: RAlgebra (CofreeF (Syntax Text) a) (Cofree (Syntax Text) a) (Maybe Identifier)
identifierAlgebra (_ :< syntax) = case syntax of
  S.Assignment f _ -> identifier f
  S.Class f _ _ -> identifier f
  S.Export f _ -> f >>= identifier
  S.Function f _ _ -> identifier f
  S.FunctionCall f _ _ -> identifier f
  S.Import f _ -> identifier f
  S.Method _ f _ _ _ -> identifier f
  S.MethodCall _ f _ _ -> identifier f
  S.Module f _ -> identifier f
  S.OperatorAssignment f _ -> identifier f
  S.SubscriptAccess f _  -> identifier f
  S.TypeDecl f _ -> identifier f
  S.VarAssignment f _ -> asum $ identifier <$> f
  _ -> Nothing
  where identifier = fmap Identifier . extractLeafValue . unwrap . fst

newtype Identifier = Identifier Text
  deriving (Eq, NFData, Show)

instance ToJSONFields Identifier where
  toJSONFields (Identifier i) = ["identifier" .= i]
