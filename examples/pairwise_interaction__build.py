#!/usr/bin/env python

from kmcos.types import *
import kmcos
from itertools import product
import numpy as np

model_name = str( os.path.basename(__file__)[+0:-3]).replace("__build", "") # This line automatically names the model based on the python file’s name. The brackets cut off zero characters from the beginning and three character from the end (".py"). The replace command removes the ‘__build’ part of the string. If you want to override this automatic naming, just set the variable ‘model_name’ equal to the string that you would like to use.
kmc_model = kmcos.create_kmc_model(model_name)
kmc_model.set_meta(author='Max J. Hoffmann',
            email='mjhoffmann@gmail.com',
            model_name='dummy_pairwise_interaction',
            model_dimension=2)

layer = kmc_model.add_layer(name='simplecubic_2d')
layer.add_site(name='a')
kmc_model.add_species(name='empty', color='#ffffff')
kmc_model.add_species(name='O', color='#ff0000',
               representation="Atoms('O')",)
kmc_model.add_species(name='CO', color='#000000',
               representation="Atoms('CO',[[0,0,0],[0,0,1.2]])",
               tags='carbon')
kmc_model.add_parameter(name='E_CO', value=-1, adjustable=True, min=-2, max=0)
kmc_model.add_parameter(name='E_CO_nn', value=.2, adjustable=True, min=-1, max=1)
kmc_model.add_parameter(name='p_COgas', value=.2, adjustable=True, scale='log', min=1e-13, max=1e3)
kmc_model.add_parameter(name='T', value=600, adjustable=True, min=300, max=1500)
kmc_model.add_parameter(name='A', value='(3*angstrom)**2')

center = kmc_model.lattice.generate_coord('a')

A = 1.  # lattice const.


kmc_model.lattice.cell = np.diag([A, A, 10])

# Adsorption process
kmc_model.add_process(name='CO_adsorption',
               conditions=[Condition(species='empty', coord=center)],
               actions=[Action(species='CO', coord=center)],
               rate_constant='p_COgas*A*bar/sqrt(2*m_CO*umass/beta)')

kmc_model.add_process(name='O_adsorption',
               conditions=[Condition(species='empty', coord=center)],
               actions=[Action(species='O', coord=center)],
               rate_constant='p_COgas*A*bar/sqrt(2*m_O*umass/beta)')

kmc_model.add_process(name='O_desorption',
               conditions=[Condition(species='O', coord=center)],
               actions=[Action(species='empty', coord=center)],
               rate_constant='p_COgas*A*bar/sqrt(2*m_O*umass/beta)')

# fetch a lot of coordinates
coords = kmc_model.lattice.generate_coord_set(size=[2, 2, 2],
                                       layer_name='simplecubic_2d')

# fetch all nearest neighbor coordinates
nn_coords = [nn_coord for i, nn_coord in enumerate(coords)
             if 0 < (np.linalg.norm(nn_coord.pos - center.pos)) <= A]

# produce all desorption processes
# using pair nearest-neighbor
# interaction
for i, nn_config in enumerate(product(['empty', 'CO'], repeat=len(nn_coords))):
    # Number of CO atoms in neighborhood
    N_CO = nn_config.count('CO')

    # rate constant with pairwise interaction
    rate_constant = 'p_COgas*A*bar/sqrt(2*m_CO*umass/beta)*exp(beta*(E_CO+%s*E_CO_nn-mu_COgas)*eV)' % N_CO

    # turn neighborhood into conditions using zip
    conditions = [Condition(coord=coord, species=species)
                  for coord, species in zip(nn_coords, nn_config)]

    # And the central site
    conditions += [Condition(species='CO', coord=center)]

    # The action: central site is empty
    actions = [Action(species='empty', coord=center)]

    kmc_model.add_process(name='CO_desorption_%s' % i,
                   conditions=conditions,
                   actions=actions,
                   rate_constant=rate_constant)

# Save the model to an xml file
###It's good to simply copy and paste the below lines between model creation files.
kmc_model.print_statistics()
kmc_model.backend = 'local_smart' #specifying is optional. 'local_smart' is the default. Currently, the other options are 'lat_int' and 'otf'
kmc_model.clear_model() #This line is optional: if you are updating a model, this line will remove the old model files (including compiled files) before exporting the new one. It is convenient to always include this line because then you don't need to 'confirm' removing/overwriting the old model during the compile step.
kmc_model.save_model()
kmcos.compile(kmc_model)
