cask 'toggltargets' do
    version '1.0.0'
    sha256 'dfe06c33974a029f7cd669ec514e5792e28dd4503a6352e4d614f2a9df51a472'
    url 'https://github.com/davila-vilanova/toggltargets/releases/download/[todo]'
    name 'TogglTargets'
    homepage 'https://github.com/davila-vilanova/toggltargets'
    app 'TogglTargets.app'
    uninstall quit: 'la.davi.TogglTargets'
              login_item: 'TogglTargets'
              trash: '/Applications/TogglTargets.app'
    zap trash: [
        '~/Library/Application Support/la.davi.TogglTargets/'
    ]
end