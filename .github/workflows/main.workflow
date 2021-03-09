name: Check and deploy to GitHub Pages
on: push

jobs:
  check-and-deploy:
    name: Check content and deploy
    runs-on: ubuntu-latest
    steps:
    - name: Checkout master
      uses: actions/checkout@v1
      with:
        submodules: true
    - name: Check for broken links
      uses: marccampbell/hugo-linkcheck-action@v0.1.3
    - name: Deploy to GitHub Pages
      uses: benmatselby/hugo-deploy-gh-pages@v1.8.0
      env:
        TARGET_REPO: pl4nty/pl4nty.github.io
        HUGO_VERSION: 0.81.0
        TARGET_BRANCH: master
        TOKEN: ${{ secrets.GITHUB_TOKEN }}
        CNAME: tplant.com.au