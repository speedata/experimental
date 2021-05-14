require "pathname"

installdir = Pathname.new(__FILE__).join("..")
srcdir   = installdir.join("src")

ENV['GOBIN'] = "#{installdir}/bin"


desc "Compile the binary"
task :build do
	Dir.chdir(srcdir.join("go")) do
		sh "go install -ldflags \"-X main.basedir=#{installdir}\" experimental/sc/sc"
	end
end
