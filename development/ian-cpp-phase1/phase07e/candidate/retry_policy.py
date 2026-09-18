"""Status eligibility is distinct from original-unit acceptance."""
import math

def usable_return(x,z,upper,objective,n,m):
 if len(x)!=n or len(z)!=m or len(upper)!=n or not math.isfinite(objective):return False
 return (all(math.isfinite(v) for v in list(x)+list(z)+list(upper))
         and all(v>0 for v,u in zip(x,upper) if u>0))

def classify_return(usable,status,objective_error,primal,absolute,stationarity,negative,gap):
 finite=all(math.isfinite(v) for v in [objective_error,primal,absolute,stationarity,negative,gap])
 checks=finite and objective_error<=1e-7 and all(v<=1e-7 for v in [primal,stationarity,negative,gap])
 accepted=bool(usable and status=='Solved' and checks)
 eligible=bool(usable and status in ['Solved','AlmostSolved'] and finite and objective_error<=1e-7
               and (status=='AlmostSolved' or not checks))
 return accepted,eligible
