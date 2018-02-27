require "pathname"

installdir = Pathname.new(__FILE__).join("..")
srcdir   = installdir.join("src")
ENV['GOPATH'] = "#{srcdir}/go"
ENV['GOBIN'] = "#{installdir}/bin"


desc "Compile the binary"
task :build do
	sh "go install -ldflags \"-X main.basedir=#{installdir}\" sc/sc "
end


desc "Update dependencies"
task :update do
	sh "go get -d sc/sc"
	Rake::Task["build"].execute
end

