# GitHub App required by the mint workflow

The mint workflow needs to create repositories in the `AMWA-TV`
organisation, push to them, and seed their secrets. `GITHUB_TOKEN`
cannot do that, so we use a dedicated GitHub App.

## Creating the App

1. Go to **AMWA-TV → Settings → Developer settings → GitHub Apps → New GitHub App**.
2. Name: `AMWA IN Index Minter` (any unique name).
3. Homepage URL: `https://github.com/AMWA-TV/in-index`.
4. Uncheck **Active** under *Webhook* (this App is polled by workflow runs, not pushed to).
5. Under **Permissions → Repository permissions**, grant:
   - **Administration:** *Read & write* — needed to create new repos.
   - **Contents:** *Read & write* — needed to push customisations to the new repo and to update `index.yml` in this repo.
   - **Metadata:** *Read* (default, required).
   - **Secrets:** *Read & write* — needed to copy `SSH_*` into new repos.
   - **Pull requests:** *Read & write* — needed to open the proposal PR.
   - **Issues:** *Read & write* — needed to comment on and close the proposal issue.
   - **Actions:** *Read* — used to look up the workflow log URL for the summary comment (optional).
6. Under **Where can this GitHub App be installed?**, select **Only on this account**.
7. Create the App, then **Generate a private key** and download the `.pem` file.
8. Under the App's **Install App** page, install it on `AMWA-TV` for **All repositories** (so it can mint any future `in-NNN`).

## Wiring it up

Add these Actions secrets to `AMWA-TV/in-index`:

| Secret name              | Value                                                       |
|--------------------------|-------------------------------------------------------------|
| `MINTER_APP_CLIENT_ID`   | The App's **Client ID** (starts with `Iv23…`) from the App's settings page (under *About*). |
| `MINTER_APP_PRIVATE_KEY` | The full contents of the downloaded `.pem`.                 |
| `SSH_USER`               | Web-server SSH username.                                    |
| `SSH_HOST`               | Web-server hostname.                                        |
| `SSH_PRIVATE_KEY`        | Web-server SSH private key (full PEM).                      |
| `SSH_KNOWN_HOSTS`        | `ssh-keyscan` output for the web-server host.               |

Note: prior to `actions/create-github-app-token@v3.1.0` the action took a
numeric `app-id` input. That input is now deprecated in favour of
`client-id`, which is why the secret is named `MINTER_APP_CLIENT_ID`.

The four `SSH_*` secrets are what get replicated into each freshly-minted
`in-NNN` repo by the mint workflow.

## Rotating the key

Regenerate the private key in the App settings, download the new `.pem`,
and replace the `MINTER_APP_PRIVATE_KEY` secret. Old keys stay valid
until you delete them from the App.
