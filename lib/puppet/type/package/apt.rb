module Puppet
    Puppet.type(:package).newpkgtype(:apt, :dpkg) do
        ENV['DEBIAN_FRONTEND'] = "noninteractive"



        # A derivative of DPKG; this is how most people actually manage
        # Debian boxes, and the only thing that differs is that it can
        # install packages from remote sites.

        def checkforcdrom
            unless defined? @@checkedforcdrom
                if FileTest.exists? "/etc/apt/sources.list"
                    if File.read("/etc/apt/sources.list") =~ /^[^#]*cdrom:/
                        @@checkedforcdrom = true
                    else
                        @@checkedforcdrom = false
                    end
                else
                    # This is basically a pathalogical case, but we'll just
                    # ignore it
                    @@checkedforcdrom = false
                end
            end

            if @@checkedforcdrom and self[:allowcdrom] != :true
                raise Puppet::Error,
                    "/etc/apt/sources.list contains a cdrom source; not installing.  Use 'allowcdrom' to override this failure."
            end
        end

        # Install a package using 'apt-get'.  This function needs to support
        # installing a specific version.
        def install
            should = self.should(:ensure)

            checkforcdrom()

            str = self[:name]
            case should
            when true, false, Symbol
                # pass
            else
                # Add the package version
                str += "=%s" % should
            end
            cmd = "/usr/bin/apt-get -q -y install %s" % str

            self.info "Executing %s" % cmd.inspect
            output = %x{#{cmd} 2>&1}

            unless $? == 0
                raise Puppet::PackageError.new(output)
            end
        end

        # What's the latest package version available?
        def latest
            cmd = "/usr/bin/apt-cache showpkg %s" % self[:name] 
            self.info "Executing %s" % cmd.inspect
            output = %x{#{cmd} 2>&1}

            unless $? == 0
                raise Puppet::PackageError.new(output)
            end

            if output =~ /Versions:\s*\n((\n|.)+)^$/
                versions = $1
                version = versions.split(/\n/).collect { |version|
                    if version =~ /^([^\(]+)\(/
                        $1
                    else
                        self.warning "Could not match version '%s'" % version
                        nil
                    end
                }.reject { |vers| vers.nil? }.sort[-1]

                unless version
                    self.debug "No latest version"
                    if Puppet[:debug]
                        print output
                    end
                end

                return version
            else
                self.err "Could not match string"
            end
        end

        def update
            self.install
        end

        def uninstall
            cmd = "/usr/bin/apt-get -y -q remove %s" % self[:name]
            output = %x{#{cmd} 2>&1}
            if $? != 0
                raise Puppet::PackageError.new(output)
            end
        end

        def versionable?
            true
        end
    end
end
