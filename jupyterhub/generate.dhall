let jupyterhub = ./package.dhall

in  jupyterhub.jupyterhub
      { adminUser = env:JH_ADMIN_USER as Text
      , adminPassword = env:JH_ADMIN_PASSWORD as Text
      , ingressHost = env:JH_INGRESS_HOST as Text
      , secretToken = env:JH_SECRET_TOKEN as Text
      }
