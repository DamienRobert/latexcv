This repository contains a script to generate different cvs from a single
yaml file (here perso.yaml).

The parsing is done by parse.rb, it is used by
- biblio.rb to generate bibtex files
- cv.rb to generate a full cv and a publication list, both in english and
  french
- An eruby script (via [webgen](http://webgen.gettalong.org/)) to generate
  web pages.

  For instance the page teaching/index.en.page uses:

      <%=
      groups=Biblio.webteach_bibgroups
      kwds={out: :web, lang: :en, cur_folder: 'teaching/'}
      Biblio.process_group(groups,$biblio, **kwds)
      %>

Obligatory warning:

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
