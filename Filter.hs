import Text.Pandoc
import Text.Pandoc.Shared
import System.Process (readProcess)
import System.Environment (getArgs)
import Data.Char (ord)
import Data.List
import Data.Maybe
-- from the utf8-string package on HackageDB:
import Data.ByteString.Lazy.UTF8 (fromString)
-- from the SHA package on HackageDB:
import Data.Digest.Pure.SHA
import Text.JSON.Generic

(|>) x y = y x
(>>|) x y = x >>= return . y

ifNull :: [b] -> a -> a -> a
ifNull l x y
    | null l    = x
    | otherwise = y

-- | Generate a unique filename given the file's contents.
uniqueName :: String -> String
uniqueName = showDigest . sha1 . fromString

-- ~~~ {include="test.py" .python}
-- This will be replaced by content of test.py.
-- ~~~
doInclude :: Block -> IO Block
doInclude cb@(CodeBlock (id, classes, namevals) contents) =
  case lookup "include" namevals of
    Just f   -> return . (CodeBlock (id, classes, namevals)) =<< readFile f
    Nothing  -> return cb
doInclude x = return x

-- ~~~ {env=theorem name=Thm1 desc=Desc #ref}
-- This is a *theorem*! $blah^{blah}$
-- ~~~
doEnv :: String -> Block -> Block
doEnv format cb@(CodeBlock (id, classes, namevals) contents) =
  case (format, lookup "env" namevals) of
      (_, Nothing)  -> cb
      (f, _) | not $ f `elem` ["latex", "html"]
                    -> cb
      (_, Just env) -> RawBlock format new_contents
         where new_contents = concat [
                                      env_wrapper_header,
                                      env_header,
                                      writer def . readMarkdown def $ contents,
                                      env_wrapper_footer
                                      ]
               name = fromMaybe "" $ lookup "name" namevals
               desc = fromMaybe "" $ lookup "desc" namevals
               (env_wrapper_header, env_wrapper_footer, env_header, writer) =
                 case format of
                   "latex" -> (
                        "\\begin{" ++ env ++ "}",
                        "\n\\end{" ++ env ++ "}\n",
                        concat [
                                ifNull name "" ("[" ++ name ++ "]"),
                                ifNull desc "" ("{" ++ desc ++ "}"),
                                ifNull id "" ("\\label{" ++ id ++ "}"),
                        "\n"],
                        writeLaTeX
                        )
                   "html"  -> (
                        concat ["<div class='", env, " ",
                                concat $ intersperse " " classes,
                                "' ",
                                ifNull id "" $ concat ["id='", id, "' "],
                                ">\n"
                                ],
                        "\n</div>\n",
                        "<span class='env-header'>" ++ name ++ desc ++ "</span>\n",
                        writeHtmlString
                        )
doEnv _ x = x

-- ~~~ {.dot name="diagram1"}
-- digraph G {Hello->World}
-- ~~~

doDot :: Block -> IO Block
doDot (CodeBlock (id, classes, namevals) contents) | "dot" `elem` classes = do
  let (name, outfile) =  case lookup "name" namevals of
                                Just fn   -> ([Str fn], fn ++ ".png")
                                Nothing   -> ([], uniqueName contents ++ ".png")
  let dotProgram = fromMaybe "dot" $ lookup "dot" namevals
  result <- readProcess dotProgram ["-Tpng", "-o", outfile] contents
  {- writeFile outfile result -}
  return $ Para [Image name (outfile, "")]
doDot x = return x

-- [](#ref)
-- In LaTeX: `\ref{ref}`, not `\hyperref[ref]{}`

doEmptyLink :: String -> Inline -> Inline
doEmptyLink format l@(Link [] ('#':ref,_)) =
    case format of
        "latex" -> RawInline "latex" $ "\\ref{" ++ ref ++ "}"
        "html"  -> l
        _       -> l
doEmptyLink _ x = x


main :: IO ()
main = do
    args <- getArgs
    let format = case args of
                    [f] -> f
                    _   -> "html"   -- default
    getContents
        >>| (decodeJSON :: String -> Pandoc)
        >>| bottomUp (doEnv format)
        >>| bottomUp (doEmptyLink format)
        >>= bottomUpM doDot
        >>= bottomUpM doInclude
        >>= putStr . encodeJSON
