require "pathname"

installdir = Pathname.new(__FILE__).join("..")
ENV['GOBIN'] = "#{installdir}/bin"


desc "Compile the binary"
task :build do
	sh "go install -ldflags \"-X main.basedir=#{installdir}\" sc/sc "
end
