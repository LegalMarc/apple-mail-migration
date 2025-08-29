# apple-mail-migration
The official migration assistant only works if you are migrating all apps. This tool migrates Mail only.

# Apple Mail Push Migration (Old Mac -> New Mac, over LAN)

Scripted, resumable migration of Apple Mail data from an old Mac to a new Mac on the same network.  
Runs entirely from the **old Mac**, requires **no extra disk space** on the old Mac, and survives **network hiccups**.

It migrates:
- Mailboxes (including "On My Mac")
- Rules, Smart Mailboxes, signatures, and layout/state
- Mail sandbox containers and support data

It does **not** copy:
- Account passwords and S/MIME private keys (those live in Keychain; see "Passwords and certificates")

## Requirements

- Both Macs are on the same network.
- The **new Mac** is on the **same macOS major version or newer** than the old Mac.  
  Check on each Mac:
  ```bash
  sw_vers -productVersion
  ```
- You can SSH from the old Mac to the new Mac.

Terminology:
- **Old Mac** = machine that currently holds your Apple Mail data
- **New Mac** = machine you are migrating to

## Permissions and one-time setup

### 1) Old Mac: grant Terminal Full Disk Access
Mandatory so the script can read `~/Library/Mail` under macOS privacy (TCC).

System Settings -> Privacy & Security -> Full Disk Access -> enable "Terminal".

### 2) New Mac: enable SSH and get its IP
- System Settings -> General -> Sharing -> enable "Remote Login".
- Find the IP:
  ```bash
  ipconfig getifaddr en0
  ```
  You will use `NEWUSER@NEW_IP` as the destination in the script.

### 3) Optional: set up an SSH key (avoids password prompts)
On the **old Mac**:
```bash
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub | ssh NEWUSER@NEW_IP 'mkdir -p ~/.ssh; chmod 700 ~/.ssh; cat >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys'
```

## Files copied by this migration

From the old Mac's home folder:
- `~/Library/Mail`  
  Actual messages, indexes, MailData.
- `~/Library/Mail Downloads`  
  Attachments you saved via Mail.
- `~/Library/Containers/com.apple.mail`  
  Sandboxed data including rules, signatures, smart mailboxes, preferences.
- `~/Library/Containers/com.apple.MailServiceAgent`
- `~/Library/Group Containers/group.com.apple.mail`  
  Present on some macOS versions.
- `~/Library/Preferences/com.apple.mail.plist` and `~/Library/Preferences/com.apple.mail-shared.plist`  
  Some builds store prefs here.
- `~/Library/Saved Application State/com.apple.mail.savedState`  
  Window/state restore.

## Using the script

1) Place the script file (for example, `push-mail-no-duplicate.sh`) on the **old Mac**.
2) Edit the line at the top that sets the destination:
   ```bash
   DEST="NEWUSER@NEW_IP"
   ```
3) Make it executable and run it on the **old Mac**:
   ```bash
   chmod +x push-mail-no-duplicate.sh
   ./push-mail-no-duplicate.sh
   ```
4) If the connection drops, run the script again. It resumes where it left off.

### Keeping both Macs awake during the transfer
The script already keeps both sides awake using `caffeinate`. If you want to run it manually ahead of time:
```bash
caffeinate -dimsu >/dev/null 2>&1 &
ssh NEWUSER@NEW_IP 'caffeinate -dimsu >/dev/null 2>&1 &'
```

## Back up any existing Mail on the new Mac (optional)

If you want to archive the new Mac's current Mail before migrating:
```bash
ssh NEWUSER@NEW_IP '
  TS=$(date +%Y%m%d-%H%M%S)
  mkdir -p ~/Mail-Migration-Backups/"$TS"
  [ -e ~/Library/Mail ] && mv ~/Library/Mail ~/Mail-Migration-Backups/"$TS"/ || true
'
```

## After migration

- Launch Mail on the **new Mac**. The first open may reindex/upgrade the mailbox format.
- If you did not migrate keychain items, Mail may prompt for each account password once.
- Verify:
  - "On My Mac" mailboxes are present
  - Rules and Smart Mailboxes exist and function
  - Signatures and account settings appear as expected

## Passwords and certificates

Passwords and S/MIME identities are **not** inside the Mail folders.

Options:
1) Use **iCloud Keychain** on both Macs under the same Apple ID to sync passwords automatically.
2) Export/import identities via the Keychain CLI on the **old Mac**:
   ```bash
   # Export all identities (cert + private key) to a password-protected PKCS#12:
   security export -k ~/Library/Keychains/login.keychain-db -t identities -f pkcs12      -P 'choose_a_strong_password' -o ~/Desktop/mail-identities.p12

   # Copy to the new Mac and import:
   security import ~/Desktop/mail-identities.p12 -k ~/Library/Keychains/login.keychain-db      -P 'choose_a_strong_password' -T /System/Applications/Mail.app
   ```

## Troubleshooting

- **"Operation not permitted" when pulling from the new Mac**  
  Do not pull. Run the script on the **old Mac** so Terminal's Full Disk Access applies to reading `~/Library/Mail`. Pulling makes `rsync` run under `sshd` on the old Mac, which lacks that access unless you explicitly grant it.

- **"rsync: empty remote host"**  
  The `DEST="NEWUSER@NEW_IP"` line was missing or not set inside the script. Edit the script and set `DEST` at the top.

- **"unrecognized option \`--info=progress2'"**  
  macOS ships an older `rsync`. Use `--progress` as in the script.

- **"File name too long" or `._` AppleDouble errors**  
  The script excludes AppleDouble and `.DS_Store` files. If you wrote your own rsync, add:
  ```bash
  --exclude '*/._*' --exclude '.DS_Store'
  ```

- **Connection reset mid-transfer**  
  Re-run the script; it resumes thanks to `--partial --inplace`. The script also enables SSH keepalives and compression.

- **Repeated password prompts**  
  Set up an SSH key as shown above, or continue entering the password.

- **Confirming success**  
  On the new Mac:
  ```bash
  du -sh ~/Library/Mail
  ls ~/Library/Mail
  ```
  Sizes may differ slightly until Mail finishes reindexing.

## Safety notes

- Do **not** migrate from a newer macOS to an older macOS. Update the new Mac first.
- The script does not delete anything on the old Mac.
- On first SSH connect you will be asked to trust the host key. Review the fingerprint and type "yes".

## Repository layout

- `push-mail-no-duplicate.sh` — main script (place your version here)
- `README.md` — this file

## License

MIT. Contributions welcome.
