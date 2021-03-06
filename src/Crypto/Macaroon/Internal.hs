{-# LANGUAGE OverloadedStrings #-}
{-|
Module      : Crypto.Macaroon.Internal
Copyright   : (c) 2015 Julien Tanguy
License     : BSD3

Maintainer  : julien.tanguy@jhome.fr
Stability   : experimental
Portability : portable


Internal representation of a macaroon
-}
module Crypto.Macaroon.Internal where


import           Control.DeepSeq
import           Crypto.Hash
import           Data.Byteable
import qualified Data.ByteString        as BS
import qualified Data.ByteString.Base64 as B64
import qualified Data.ByteString.Char8  as B8
import           Data.Hex
import           Data.List


-- |Type alias for Macaroons secret keys
type Secret = BS.ByteString

-- |Type alias for Macaroons and Caveat and identifiers
type Key = BS.ByteString

-- |Type alias for Macaroons and Caveat locations
type Location = BS.ByteString

-- |Type alias for Macaroons signatures
type Sig = BS.ByteString

-- | Main structure of a macaroon
data Macaroon = MkMacaroon { location   :: Location
                           -- ^ Target location
                           , identifier :: Key
                           -- ^ Macaroon Identifier
                           , caveats    :: [Caveat]
                           -- ^ List of caveats
                           , signature  :: Sig
                           -- ^ Macaroon HMAC signature
                           }

-- | Constant-time Eq instance
instance Eq Macaroon where
    (MkMacaroon l1 i1 c1 s1) == (MkMacaroon l2 i2 c2 s2) =
        (l1 `constEqBytes` l2) &&!
        (i1 `constEqBytes` i2) &&!
        (c1 == c2) &&!
        (s1 `constEqBytes` s2)


-- | show instance conforming to the @inspect@ "specification"
instance Show Macaroon where
    -- We use intercalate because unlines would add a trailing newline
    show (MkMacaroon l i c s) = intercalate "\n" [
                      "location " ++ B8.unpack l
                    , "identifier " ++ B8.unpack i
                    , intercalate "\n" (map show c)
                    , "signature " ++ B8.unpack (hex s)
                    ]

-- | NFData instance for use in the benchmark
instance NFData Macaroon where
    rnf (MkMacaroon loc ident cavs sig) = rnf loc `seq` rnf ident `seq` rnf cavs `seq` rnf sig


-- | Caveat structure
data Caveat = MkCaveat { cid :: Key
                       -- ^ Caveat identifier
                       , vid :: Key
                       -- ^ Caveat verification key identifier
                       , cl  :: Location
                       -- ^ Caveat target location
                       }

-- | Constant-time Eq instance
instance Eq Caveat where
    (MkCaveat c1 v1 l1) == (MkCaveat c2 v2 l2) =
        (c1 `constEqBytes` c2) &&!
        (v1 `constEqBytes` v2) &&!
        (l1 `constEqBytes` l2)

-- | show instance conforming to the @inspect@ "specification"
instance Show Caveat where
    show (MkCaveat c v l) | v == BS.empty = "cid " ++ B8.unpack c
                          | otherwise = unlines [ "cid " ++ B8.unpack c
                                                , "vid " ++ B8.unpack v
                                                , "cl " ++ B8.unpack l
                                                ]


-- | NFData instance for use in the benchmark
instance NFData Caveat where
    rnf (MkCaveat cid vid cl) = rnf cid `seq` rnf vid `seq` rnf cl

-- | Primitive to add a First or Third party caveat to a macaroon
-- For internal use only
addCaveat :: Location
          -> Key
          -> Key
          -> Macaroon
          -> Macaroon
addCaveat loc cid vid m = m { caveats = cavs ++ [cav'], signature = sig}
  where
    cavs = caveats m
    cav' = MkCaveat cid vid loc
    sig = toBytes (hmac (signature m) (BS.append vid cid) :: HMAC SHA256)

-- | Utility non-short circuiting '&&' function.
(&&!) :: Bool -> Bool -> Bool
True  &&! True  = True
True  &&! False = False
False &&! True  = False
False &&! False = False

