{-# LANGUAGE AllowAmbiguousTypes #-}

module Main (main) where

import Data.ByteString (ByteString)
import Data.Default (def)

import Test.Tasty
import Test.Tasty.HUnit

import Plutarch.Api.V1 as PLedgerV1
import Plutarch.Api.V2 as PLedgerV2
import Plutarch.Prelude
import PlutusLedgerApi.V1
import qualified PlutusTx.AssocMap as PlutusMap

import Ply (ScriptRole (MintingPolicyRole, ValidatorRole), ScriptVersion (ScriptV1, ScriptV2), Typename, typeName)
import Ply.Plutarch.TypedWriter (TypedWriter, typedWriterInfo)

-- | Ensure 'typedWriterInfo @ptype' yields the expected 'ScriptRole' and '[Typename]'.
testHelper ::
  forall ptypeList.
  ( TypedWriter (PTypeWith PLedgerV1.PValidator ptypeList)
  , TypedWriter (PTypeWith PLedgerV1.PMintingPolicy ptypeList)
  , TypedWriter (PTypeWith PLedgerV2.PValidator ptypeList)
  , TypedWriter (PTypeWith PLedgerV2.PMintingPolicy ptypeList)
  ) =>
  [Typename] ->
  Assertion
testHelper expectedTypes = do
  let (actualVersion0, actualRole0, actualTypes0, _) =
        typedWriterInfo @(PTypeWith PLedgerV1.PValidator ptypeList) def undefined
  actualRole0 @?= ValidatorRole
  let (actualVersion1, actualRole1, actualTypes1, _) =
        typedWriterInfo @(PTypeWith PLedgerV1.PMintingPolicy ptypeList) def undefined
  actualRole1 @?= MintingPolicyRole
  actualVersion0 @?= ScriptV1
  actualVersion0 @?= actualVersion1
  let (actualVersion2, actualRole2, actualTypes2, _) =
        typedWriterInfo @(PTypeWith PLedgerV2.PValidator ptypeList) def undefined
  actualRole2 @?= ValidatorRole
  let (actualVersion3, actualRole3, actualTypes3, _) =
        typedWriterInfo @(PTypeWith PLedgerV2.PMintingPolicy ptypeList) def undefined
  actualRole3 @?= MintingPolicyRole
  actualVersion2 @?= ScriptV2
  actualVersion2 @?= actualVersion3
  actualTypes0 @?= expectedTypes
  actualTypes0 @?= actualTypes1
  actualTypes0 @?= actualTypes2
  actualTypes0 @?= actualTypes3

baselineTest :: Assertion
baselineTest = testHelper @'[] []

tests :: TestTree
tests =
  testGroup
    "typedWriterInfo works as expected"
    [ testCase "@PValidator/@PMintingPolicy" baselineTest
    , testCase "@(PBool :--> _)" $
        testHelper @'[PBool] [typeName @Bool]
    , testCase "@(PInteger :--> PUnit :--> PByteString :--> _)" $
        testHelper @'[PBool, PUnit, PByteString]
          [ typeName @Bool
          , typeName @()
          , typeName @ByteString
          ]
    , testCase
        ( "@(PBuiltinPair PValue PCredential "
            ++ ":--> PCurrencySymbol :--> PPOSIXTime :--> PInterval PInteger :--> _)"
        )
        $ testHelper
          @'[ PBuiltinPair (PValue Sorted NonZero) PCredential
            , PCurrencySymbol
            , PPOSIXTime
            , PInterval PInteger
            ]
          [ typeName @(Value, Credential)
          , typeName @CurrencySymbol
          , typeName @POSIXTime
          , typeName @(Interval Integer)
          ]
    , testCase
        ( "@(PBuiltinList PTxInInfo "
            ++ ":--> PTxOutRef :--> PExtended PInteger :--> PPubKeyHash "
            ++ ":--> PMaybeData PByteString :--> PMap PDatumHash PDatum :--> _)"
        )
        $ testHelper
          @'[ PBuiltinList PLedgerV1.PTxInInfo
            , PTxOutRef
            , PExtended PInteger
            , PPubKeyHash
            , PMaybeData PByteString
            , PMap Sorted PDatumHash PDatum
            ]
          [ typeName @[TxInInfo]
          , typeName @TxOutRef
          , typeName @(Extended Integer)
          , typeName @PubKeyHash
          , typeName @(Maybe ByteString)
          , typeName @(PlutusMap.Map DatumHash Datum)
          ]
    ]

main :: IO ()
main = defaultMain tests

type PTypeWith :: PType -> [PType] -> PType
type family PTypeWith e xs = r where
  PTypeWith e '[] = e
  PTypeWith e (x : xs) = x :--> PTypeWith e xs
