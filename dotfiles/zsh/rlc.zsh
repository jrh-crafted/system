# --------------------------------------------
# RLC: Databases

alias dbp='rlc__sync_database production'
alias dbr='rlc__reload_database'
alias dbs='rlc__sync_database staging'

rlc__reload_database() {
  local env="$1"

  if [[ "$env" != "staging" && "$env" != "production" ]]; then
    echo "Usage: rlc__reload_database [staging|production]"
    return 1
  fi

  local backup_file
  local local_db

  if [[ "$env" == "production" ]]; then
    backup_file="$(pwd)/db/backup/production.dump"
    local_db="rlc"
  else
    backup_file="$(pwd)/db/backup/staging.dump"
    heroku_app="rlc-staging-master"
    heroku_db="postgresql-cubed-23345"
    local_db="rlc_staging"
  fi

  echo "🔃 Reloading '$local_db' from '$backup_file'..."
  PGPASSWORD=$PG__PASSWORD pg_restore --verbose --clean --no-acl --no-owner -h localhost -U postgres -d "$local_db" "$backup_file"
  echo "✅ '$local_db' reloaded from '$backup_file'."
}

rlc__sync_database() {
  local env="$1"

  if [[ "$env" != "staging" && "$env" != "production" ]]; then
    echo "Usage: rlc__sync_database [staging|production]"
    return 1
  fi

  local backup_file
  local heroku_app_name
  local heroku_db
  local local_db

  if [[ "$env" == "production" ]]; then
    backup_file="$(pwd)/db/backup/production.dump"
    heroku_app="rescuingleftovercuisine"
    heroku_db="postgresql-pointy-06631"
    local_db="rlc"
  else
    backup_file="$(pwd)/db/backup/staging.dump"
    heroku_app="rlc-staging-master"
    heroku_db="postgresql-cubed-23345"
    local_db="rlc_staging"
  fi

  echo "📥 Backing up database from Heroku app '$heroku_app' ($heroku_db)..."
  if heroku pg:backups:capture "$heroku_db" --app "$heroku_app"; then
    echo "✅ Backup created on Heroku."
  else
    echo "❌ Failed to create backup on Heroku."
    return 1
  fi

  if [[ -f "$backup_file" ]]; then
    echo "🗑️  Removing existing backup file '$backup_file'..."
    rm -f "$backup_file"
  fi

  echo "⬇️  Downloading backup to '$backup_file'..."
  if heroku pg:backups:download --output "$backup_file" --app "$heroku_app"; then
    echo "✅ Backup downloaded successfully."
  else
    echo "❌ Failed to download backup."
    return 1
  fi

  echo "🔄 Syncing backup with local database '$local_db'..."
  PGPASSWORD=$PG__PASSWORD pg_restore --verbose --clean --no-acl --no-owner -h localhost -U postgres -d "$local_db" "$backup_file"

  echo "✅ Database synced."
}

# --------------------------------------------
# RLC: Git

alias gs='rlc__stage_latest_commit'

rlc__stage_latest_commit() {
  local original_branch=$(git branch --show-current)

  local latest_commit_id=$(git rev-parse HEAD)
  local latest_commit_message=$(git log -1 --pretty=format:"%s" "$latest_commit_id")
  echo "📝 Staging commit: '$latest_commit_message' from branch '$original_branch'."

  echo "🔄 Switching to branch 'staging'..."
  if ! git checkout staging; then
    echo "🔄 Error: Failed to switch to branch 'staging'."
    return 1
  fi

  echo "⬇️  Pulling latest changes on branch 'staging'..."
  if ! git pull; then
    echo "⬇️ Error: Failed to pull from branch 'staging'."
    git checkout "$original_branch"
    return 1
  fi

  # Cherry pick the stored commit
  echo "🍒 Cherry-picking commit '$latest_commit_id'..."
  if ! git cherry-pick "$latest_commit_id"; then
    echo "🍒 Error: Failed to cherry-pick commit '$latest_commit_id'."
    git checkout "$original_branch"
    return 1
  fi

  echo "⬆️  Pushing branch 'staging'..."
  if ! git push; then
    echo "⬆️ Error: Failed to push branch 'staging'."
    git checkout "$original_branch"
    return 1
  fi

  echo "↩️ Switching back to '$original_branch'..."
  if ! git checkout "$original_branch"; then
    echo "↩️ Error: Failed to switch back to original branch '$original_branch'."
    return 1
  fi

  echo "✅ Successfully staged $latest_commit_message."
}

# --------------------------------------------
# RLC: Workflow

alias rlci='rlc__initialize'

rlc__initialize() {
  local original_branch=$(git branch --show-current)

  echo "🔄 Switching to branch 'master'..."
  git checkout master

  echo "⬇️  Pulling latest changes on branch 'master'..."
  if ! git pull; then
    echo "⬇️ Error: Failed to pull from branch 'master'."
    git checkout "$original_branch"
    return 1
  fi

  echo "🔄 Switching to branch 'staging'..."
  git checkout staging

  echo "⬇️  Pulling latest changes on branch 'staging'..."
  if ! git pull; then
    echo "⬇️ Error: Failed to pull from branch 'staging'."
    git checkout "$original_branch"
    return 1
  fi

  echo "↩️ Switching back to '$original_branch'..."
  if ! git checkout "$original_branch"; then
    echo "↩️ Error: Failed to switch back to original branch '$original_branch'."
    return 1
  fi

  echo "✅ Successfully initialized."
}
