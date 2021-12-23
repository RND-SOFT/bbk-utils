D = Steep::Diagnostic

target :lib do
  signature 'sig'
  check 'lib'
  library 'uri', 'logger', 'monitor'

  configure_code_diagnostics(D::Ruby.strict)
  # for supress splat args in passing params to send method in ProxyLogger method_missing
  configure_code_diagnostics(D::Ruby::UnsupportedSyntax => nil)
end
