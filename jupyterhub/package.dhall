{ jupyterhub =
    \ ( config
      : { adminUser : Text
        , adminPassword : Text
        , ingressHost : Text
        , secretToken : Text
        }
      ) ->
      { auth =
        { admin.users = [ config.adminUser ]
        , whitelist.users = [ config.adminUser ]
        , dummy.password = config.adminPassword
        , type = "dummy"
        }
      , ingress = { enabled = True, hosts = [ config.ingressHost ] }
      , proxy.secretToken = config.secretToken
      , singleuser =
        { image = { name = "jupyter/minimal-notebook", tag = "2343e33dec46" }
        , profileList =
          [ { default = Some True
            , description = "To avoid too much bells and whistles"
            , display_name = "Minimal Environment"
            , kubespawner_override =
                None
                  { image : Text
                  , lifecycle_hooks :
                      Optional
                        { postStart : { exec : { command : List Text } } }
                  }
            }
          , { default = None Bool
            , description =
                "If you want the additional bells and whistles: Python, R, and Julia."
            , display_name = "Datascience Environment"
            , kubespawner_override = Some
              { image = "jupyter/datascience-notebook:2343e33dec46"
              , lifecycle_hooks =
                  None { postStart : { exec : { command : List Text } } }
              }
            }
          , { default = None Bool
            , description = "The Jupyter Stacks spark image!"
            , display_name = "Spark Environment"
            , kubespawner_override = Some
              { image = "jupyter/all-spark-notebook:2343e33dec46"
              , lifecycle_hooks =
                  None { postStart : { exec : { command : List Text } } }
              }
            }
          , { default = None Bool
            , description = "The ihaskell image!"
            , display_name = "Ihaskell Environment"
            , kubespawner_override = Some
              { image = "crosscompass/ihaskell-notebook:3c46e409a47b"
              , lifecycle_hooks =
                  None { postStart : { exec : { command : List Text } } }
              }
            }
          , { default = None Bool
            , description = "Datascience Environment with Sample Notebooks"
            , display_name = "Learning Data Science"
            , kubespawner_override = Some
              { image = "jupyter/datascience-notebook:2343e33dec46"
              , lifecycle_hooks = Some
                { postStart.exec.command =
                  [ "sh"
                  , "-c"
                  , ''
                    gitpuller https://github.com/data-8/materials-fa17 master materials-fa;
                    ''
                  ]
                }
              }
            }
          ]
        }
      }
}
