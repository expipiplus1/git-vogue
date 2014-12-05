{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RecordWildCards       #-}
module Git.Vogue where

import           Control.Monad
import           Control.Monad.Base
import           Control.Monad.IO.Class      ()
import           Control.Monad.Trans.Control
import           Data.List
import           Data.Maybe
import           Data.Monoid
import           System.Directory
import           System.Exit
import           System.FilePath
import           System.Posix.Files
import           System.Process

import           Paths_git_vogue

-- | Command string to insert into pre-commit hooks.
preCommitCommand :: String
preCommitCommand = "git-vogue check"

-- | Commands, with parameters, to be executed.
data VogueCommand
    -- | Add git-vogue support to a git repository.
    = CmdInit { templatePath :: Maybe FilePath }
    -- | Verify that support is installed and plugins happen.
    | CmdVerify
    -- | Run check plugins on a git repository.
    | CmdRunCheck
    -- | Run fix plugins on a git repository.
    | CmdRunFix
  deriving (Eq, Show)

-- | Execute a git-vogue command.
runCommand
    :: VogueCommand
    -> IO ()
runCommand CmdInit{..} = runWithRepoPath (gitAddHook templatePath)
runCommand CmdVerify = error "Not implemented: verify"
runCommand CmdRunCheck = error "Not implemented: check"
runCommand CmdRunFix = error "Not implemented: fix"

-- | Find the git repository path and pass it to an action.
--
-- Throws an error if the PWD is not in a git repo.
runWithRepoPath
    :: MonadBaseControl IO m
    => (FilePath -> m a)
    -> m a
runWithRepoPath action = do
    -- Get the path to the git repo top-level directory.
    git_repo <- liftBase $ readProcess "git" ["rev-parse", "--show-toplevel"] ""
    action $ trim git_repo

-- | Add the git pre-commit hook.
gitAddHook
    :: Maybe FilePath -- ^ Template path
    -> FilePath -- ^ Hook path
    -> IO ()
gitAddHook template path = do
    let hook = path </> ".git" </> "hooks" </> "pre-commit"
    exists <- fileExist hook
    if exists
        then updateHook hook
        else createHook hook
  where
    createHook = copyHookTemplateTo template
    updateHook hook = do
        content <- readFile hook
        unless (preCommitCommand `isInfixOf` content) $ do
            putStrLn $ "A pre-commit hook already exists at \n\t"
                <> hook
                <> "\nbut it does not contain the command\n\t"
                <> preCommitCommand
                <> "\nPlease edit the hook and add this command yourself!"
            exitFailure
        putStrLn "Your commit hook is already in place."

-- | Copy the template pre-commit hook to a git repo.
copyHookTemplateTo
    :: Maybe FilePath
    -> FilePath
    -> IO ()
copyHookTemplateTo use_template hook = do
    default_template <- getDataFileName "templates/pre-commit"
    let template = fromMaybe default_template use_template
    copyFile template hook
    perm <- getPermissions hook
    setPermissions hook $ perm { executable = True }

-- | Trim whitespace from a string.
trim :: String -> String
trim = dropWhile ws . dropWhileEnd ws
  where
    ws = (`elem` " \t\n")