require "pathname"

installdir = Pathname.new(__FILE__).join("..")
srcdir   = installdir.join("src")
ENV['GOPATH'] = "#{srcdir}/go"
ENV['GOBIN'] = "#{installdir}/bin"


desc "Compile the binary"
task :default do
	sh "go install -ldflags \"-X main.basedir=#{installdir}\" sc/sc "
end
