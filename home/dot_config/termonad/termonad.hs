{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Lens ((&), set)
import Data.Colour.SRGB (sRGB24)
import Data.Singletons (sing)
import Termonad.App (defaultMain)
import Termonad.Config
import Termonad.Config.Colour
import Termonad.Config.Vec (Fin, N4, Sing, fin_, setAtVec)

main :: IO ()
main = do
  print "running termonad from default file!!!"
  let colConf =
        defaultColourConfig
          { cursorBgColour = Set $ createColour 204 0 0
          , palette =
              let myStandardColors =
                    setAtVec (fin_ (sing :: Sing N4)) (createColour 90 90 250) $
                    defaultStandardColours
                  myLightCols =
                    setAtVec (fin_ (sing :: Sing N4)) (createColour 150 150 250) $
                    defaultLightColours
              in ExtendedPalette myStandardColors myLightCols
          -- , foregroundColour = Set (createColour 220 50 50)
          -- , backgroundColour = Set (createColour 50 50 50)
          }
  colExt <- createColourExtension colConf
  let tmConf =
        defaultTMConfig
          { options =
              defaultConfigOptions
                { fontConfig =
                    FontConfig
                      { fontFamily = "DejaVu Sans Mono"
                      , fontSize = FontSizePoints 13
                      }
                , showScrollbar = ShowScrollbarAlways
                , scrollbackLen = 20000
                , confirmExit = False
                , showTabBar = ShowTabBarIfNeeded
                , showMenu = False
                }
          }
        `addColourExtension` colExt
  defaultMain tmConf
