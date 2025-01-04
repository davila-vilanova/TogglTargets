cask 'toggltargets' do
    version '1.1.0'
    sha256 '4b8b69efb64946aba151747005abd40136e0108b54d82e7bc3ff4cbc174847d3'
    url 'https://github.com/davila-vilanova/TogglTargets/releases/download/v1.1/TogglTargets.dmg'
    name 'TogglTargets'
    homepage 'https://github.com/davila-vilanova/TogglTargets'
    app 'TogglTargets.app'
    uninstall quit: 'la.davi.TogglTargets'
    uninstall login_item: 'TogglTargets'
    zap trash: [
        '~/Library/Application Support/la.davi.TogglTargets/'
    ]
end
