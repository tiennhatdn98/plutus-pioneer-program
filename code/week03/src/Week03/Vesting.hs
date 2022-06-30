{-# LANGUAGE DataKinds           #-}
{-# LANGUAGE DeriveAnyClass      #-}
{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell     #-}
{-# LANGUAGE TypeApplications    #-}
{-# LANGUAGE TypeFamilies        #-}
{-# LANGUAGE TypeOperators       #-}

{-# OPTIONS_GHC -fno-warn-unused-imports #-}

module Week03.Vesting where

import           Control.Monad        hiding (fmap)
import           Data.Aeson           (ToJSON, FromJSON)
import           Data.Map             as Map
import           Data.Text            (Text)
import           Data.Void            (Void)
import           GHC.Generics         (Generic)
import           Plutus.Contract
import           PlutusTx             (Data (..))
import qualified PlutusTx
import           PlutusTx.Prelude     hiding (Semigroup(..), unless)
import           Ledger               hiding (singleton)
import           Ledger.Constraints   (TxConstraints)
import qualified Ledger.Constraints   as Constraints
import qualified Ledger.Typed.Scripts as Scripts
import           Ledger.Ada           as Ada
import           Playground.Contract  (printJson, printSchemas, ensureKnownCurrencies, stage, ToSchema)
import           Playground.TH        (mkKnownCurrencies, mkSchemaDefinitions)
import           Playground.Types     (KnownCurrency (..))
import           Prelude              (IO, Semigroup (..), Show (..), String)
import           Text.Printf          (printf)

data VestingDatum = VestingDatum
    { beneficiary :: PaymentPubKeyHash
    , deadline    :: POSIXTime
    } deriving Show

PlutusTx.unstableMakeIsData ''VestingDatum

{-# INLINABLE mkValidator #-}
mkValidator :: VestingDatum -> () -> ScriptContext -> Bool
mkValidator dat () ctx = traceIfFalse "beneficiary's signature missing" signedByBeneficiary &&
                         traceIfFalse "deadline not reached" deadlineReached
  where
    info :: TxInfo
    info = scriptContextTxInfo ctx
    -- Constructor ScriptContent {scripContextTxInfo :: TxInfo, scriptContextPurpose :: ScriptPurpose}

    signedByBeneficiary :: Bool
    signedByBeneficiary = txSignedBy info $ unPaymentPubKeyHash $ beneficiary dat
    -- Constructor PaymentPubKeyHash {unPaymentPubKeyHash :: PubKeyHash}
    -- txSignedBy :: TxInfo -> PubKeyHash -> Bool: Check if a transaction was signed by the given public key

    deadlineReached :: Bool
    deadlineReached = contains (from $ deadline dat) $ txInfoValidRange info
    -- txInfoValidRange :: POSIXTimeRange -> The validate range for the transaction
    --                       (validate range)
    --                            ↑
    --                       [--------]
    -- ------------------|-------------------->
    --               deadline 
    -- Deadline range should contains validate range is fine

data Vesting
instance Scripts.ValidatorTypes Vesting where
    type instance DatumType Vesting = VestingDatum
    type instance RedeemerType Vesting = ()

typedValidator :: Scripts.TypedValidator Vesting
typedValidator = Scripts.mkTypedValidator @Vesting
    $$(PlutusTx.compile [|| mkValidator ||])
    $$(PlutusTx.compile [|| wrap ||])
  where
    wrap = Scripts.wrapValidator @VestingDatum @()

validator :: Validator
validator = Scripts.validatorScript typedValidator

valHash :: Ledger.ValidatorHash
valHash = Scripts.validatorHash typedValidator

scrAddress :: Ledger.Address
scrAddress = scriptAddress validator

data GiveParams = GiveParams
    { gpBeneficiary :: !PaymentPubKeyHash
    , gpDeadline    :: !POSIXTime
    , gpAmount      :: !Integer
    } deriving (Generic, ToJSON, FromJSON, ToSchema)

type VestingSchema =
            Endpoint "give" GiveParams
        .\/ Endpoint "grab" ()

give :: AsContractError e => GiveParams -> Contract w s e ()
give gp = do
    let dat = VestingDatum
                { beneficiary = gpBeneficiary gp
                , deadline    = gpDeadline gp
                }
        tx  = Constraints.mustPayToTheScript dat $ Ada.lovelaceValueOf $ gpAmount gp
    ledgerTx <- submitTxConstraints typedValidator tx
    void $ awaitTxConfirmed $ getCardanoTxId ledgerTx
    logInfo @String $ printf "made a gift of %d lovelace to %s with deadline %s"
        (gpAmount gp)
        (show $ gpBeneficiary gp)
        (show $ gpDeadline gp)

grab :: forall w s e. AsContractError e => Contract w s e ()
grab = do
    now   <- currentTime
    -- currentTime :: forall w s e. AsContractError e => Contract w s e POSIXTime: get the latest time of the current slot
    -- If slot length is 3s and current slot is 2, then currentTime returns the value `POSIXTime 5`
    pkh   <- ownPaymentPubKeyHash
    -- ownPaymentPubKeyHash :: forall w s e. AsContractError e => Contract w s e PaymentPubKeyHash: Get the hash of a public key belonging to the wallet that runs this contract
    -- Any funds paid to this public key hash will be treated as the wallet's own funds
    utxos <- Map.filter (isSuitable pkh now) <$> utxosAt scrAddress
    -- utxosAt :: forall w s e. AsContractError e => Address -> Contract w s e (Map TxOutRef ChainIndexTxOut): 
    -- Get the unspent transaction outputs at an address
    if Map.null utxos
        then logInfo @String $ "no gifts available"
        else do
            let orefs   = fst <$> Map.toList utxos
                lookups = Constraints.unspentOutputs utxos  <>
                          Constraints.otherScript validator
                tx :: TxConstraints Void Void
                tx      = mconcat [Constraints.mustSpendScriptOutput oref unitRedeemer | oref <- orefs] <>
                          Constraints.mustValidateIn (from now)
            ledgerTx <- submitTxConstraintsWith @Void lookups tx
            void $ awaitTxConfirmed $ getCardanoTxId ledgerTx
            logInfo @String $ "collected gifts"
  where
    isSuitable :: PaymentPubKeyHash -> POSIXTime -> ChainIndexTxOut -> Bool
    isSuitable pkh now o = case _ciTxOutDatum o of
        -- data ChainIndexTxOut = 
        --     PublicKeyChainIndexTxOut {
        --         _ciTxOutAddress :: Address
        --         _ciTxOutValue :: Value
        --     }
        --     | ScriptChainIndexTxOut {
        --         _ciTxOutAddress :: Address
        --         _ciTxOutValidator :: Either ValidatorHash Validator
        --         _ciTxOutDatum :: Either DatumHash Datum
        --         _ciTxOutValue :: Value
        --     }
        Left _          -> False
        Right (Datum e) -> case PlutusTx.fromBuiltinData e of
            -- fromBuiltinData :: BuiltinData -> Maybe a: convert a value from BuiltinData, return Nothing if this fails
            Nothing -> False
            Just d  -> beneficiary d == pkh && deadline d <= now

endpoints :: Contract () VestingSchema Text ()
endpoints = awaitPromise (give' `select` grab') >> endpoints
  where
    give' = endpoint @"give" give
    grab' = endpoint @"grab" $ const grab

mkSchemaDefinitions ''VestingSchema

mkKnownCurrencies []
