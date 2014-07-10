python_pkgs = value_for_platform_family(
                  "debian"  => ["python","python-dev"],
                  "rhel"    => ["python","python-devel"],
                  "fedora"  => ["python","python-devel"],
                  "freebsd" => ["python"],
                  "smartos" => ["python27"],
                  "default" => ["python","python-dev"]
)
python_pkgs.each do |pkg|
  package pkg do
    action :upgrade
  end
end
