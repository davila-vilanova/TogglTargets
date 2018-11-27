cask 'toggltargets' do
    version '1.0.0'
    sha256 'dfe06c33974a029f7cd669ec514e5792e28dd4503a6352e4d614f2a9df51a472'
    url 'https://github.com/davila-vilanova/TogglTargets/releases/download/v1.0/TogglTargets.dmg'
    name 'TogglTargets'
    homepage 'https://github.com/davila-vilanova/TogglTargets'
    app 'TogglTargets.app'
    uninstall quit: 'la.davi.TogglTargets'
    uninstall login_item: 'TogglTargets'
    uninstall trash: '/Applications/TogglTargets.app'
    zap trash: [
        '~/Library/Application Support/la.davi.TogglTargets/'
    ]
end