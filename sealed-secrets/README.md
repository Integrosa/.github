# Sealing certificate of the integrosa-platform cluster

`cert.pem` is the public key of the cluster's Sealed Secrets controller. Use it to encrypt an app
secret for your tenant namespace with `kubeseal --cert cert.pem`; only the controller inside the
cluster can decrypt the result. The file is public by design: anyone can encrypt with it, nobody
outside the cluster can decrypt. A sealed secret is bound to its namespace and name (`strict`
scope), so a copy in another namespace does not decrypt.

The source of truth is `platform/sealed-secrets/cert.pem` in the platform repository
(integrosa_platform); the platform's `verify-platform` checks that this copy is identical. The
controller adds a new key once a year and this file is then updated. Secrets sealed with an older
certificate keep working (old keys stay in the cluster); seal new ones with the current file.

Seal a value read from standard input, never from the command line (it would stay in shell history):

```bash
printf '%s' "$VALUE" | kubectl create secret generic <name> -n <namespace> \
  --from-file=<KEY>=/dev/stdin --dry-run=client -o json \
  | kubeseal --cert cert.pem -o yaml > deploy/chart/templates/sealedsecret.yaml
```

Add or change one value in an existing file: the same with
`kubeseal --cert cert.pem -o yaml --merge-into deploy/chart/templates/sealedsecret.yaml`.

Commit the SealedSecret, never a plain `Secret`: the deploy workflow (`reusable-helm-deploy`)
and the cluster both refuse a plain Secret (integrosa_platform ADR 0029, ADR 0033). A secret that
reached git in the clear must be changed at its source.
